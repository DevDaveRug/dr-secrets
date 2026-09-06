# =============================================================================
# get-secrets.ps1 -- Helper canonique pour obtenir secrets.env decrypte
# =============================================================================
# S136a-ccdd, IDEE_infra_149 livree.
#
# BUT : abstraire la source des secrets pour que les scripts CCDD (Node, PS,
# n8n exports) n aient pas a connaitre le mecanisme sous-jacent.
#
# STATUT S136a-ccdd -> S138 :
#   -> Aujourd hui : le fichier local C:\Users\conta\.cc-secrets\secrets.env
#      reste utilisable pour la parite. Ce helper le retourne s il est present.
#   -> Post-S138 : le fichier local est supprime. Ce helper le reconstitue a
#      la volee via bw get notes | age -d dans un fichier temp ephemere.
#
# Le script d appel n a rien a changer. La source bascule proprement de
# fichier local -> fichier temp reconstitue.
#
# USAGE :
#   $env_file = & "C:\Users\conta\dev\dr-secrets\scripts\get-secrets.ps1"
#   Get-Content $env_file  # lecture des lignes NOM=valeur
#
#   ou pour purger le temp :
#   & "C:\Users\conta\dev\dr-secrets\scripts\get-secrets.ps1" -Purge
#
# =============================================================================

param(
    [switch]$Purge,
    [switch]$ForceRegen
)

$LOCAL_FILE  = "C:\Users\conta\.cc-secrets\secrets.env"
$TMP_FILE    = Join-Path $env:USERPROFILE "Documents\secrets-tmp.env"
$SECRETS_AGE = "C:\Users\conta\dev\dr-secrets\secrets.env.age"
$BW_ITEM     = "age keys.txt dr-secrets"

# ---- Purge ----
if ($Purge) {
    Remove-Item $TMP_FILE -Force -ErrorAction SilentlyContinue
    return
}

# ---- Priorite 1 : fichier local s il existe (transitoire S136a -> S138) ----
if ((Test-Path $LOCAL_FILE) -and (-not $ForceRegen)) {
    return $LOCAL_FILE
}

# ---- Priorite 2 : temp encore frais (moins de 8h) ----
if ((Test-Path $TMP_FILE) -and (-not $ForceRegen)) {
    $ageHours = ((Get-Date) - (Get-Item $TMP_FILE).LastWriteTime).TotalHours
    if ($ageHours -lt 8) {
        return $TMP_FILE
    }
}

# ---- Priorite 3 : reconstitue via bw get notes | age -d ----
if (-not (Get-Command bw  -ErrorAction SilentlyContinue)) { throw "bw introuvable dans PATH." }
if (-not (Get-Command age -ErrorAction SilentlyContinue)) { throw "age introuvable dans PATH." }
if (-not (Test-Path $SECRETS_AGE))                        { throw "secrets.env.age introuvable : $SECRETS_AGE" }

# Session BW
$status = (& bw status) | ConvertFrom-Json
if ($status.status -eq "unauthenticated") { throw "bw login requis. Fais 'bw login' d abord." }
if ($status.status -eq "locked" -or -not $env:BW_SESSION) {
    Write-Host "[get-secrets] bw unlock (tape master password) :" -ForegroundColor Yellow
    $env:BW_SESSION = (& bw unlock --raw)
    if (-not $env:BW_SESSION) { throw "bw unlock a echoue." }
}

# Fetch note + join newlines correct (piege documente Test B S136a)
$notesArr = (& bw get notes $BW_ITEM --session $env:BW_SESSION)
$notesStr = ($notesArr -join "`n") + "`n"

$tmpKey = Join-Path $env:TEMP "get-secrets-key.txt"
[System.IO.File]::WriteAllText($tmpKey, $notesStr, (New-Object System.Text.UTF8Encoding($false)))

try {
    $decryptOut = (& age -d -i $tmpKey $SECRETS_AGE) 2>&1
    if ($LASTEXITCODE -ne 0) { throw "age -d a echoue : $decryptOut" }
    [System.IO.File]::WriteAllText($TMP_FILE, ($decryptOut -join "`n"), (New-Object System.Text.UTF8Encoding($false)))
} finally {
    Remove-Item $tmpKey -Force -ErrorAction SilentlyContinue
}

return $TMP_FILE

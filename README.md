# dr-secrets — secrets chiffres age (repo PUBLIC)

Ce repo **PUBLIC** contient **le seul fichier** `secrets.env.age` : les secrets de David chiffres avec `age`, portables entre CCWeb, CCDD, PowerShell local et Codespace.

Correspond a **IDEE_infra_129** (Bootstrap secrets portable methode B) — voir `dr-context/docs/DR/DR_Professionnel/IDEAS_PRO.md`.

**MAJ S136a-ccdd (IDEE_infra_149 LIVREE)** : pipeline `bw get notes | age -d` valide bout en bout. La cle privee `age` est stockee dans Bitwarden vault (note `age keys.txt dr-secrets`). Le fichier local `C:\Users\conta\.cc-secrets\secrets.env` devient transitoire (supprime session S138 apres 2-3 sessions de validation en production).

**MAJ S137a-ccdd (IDEE_infra_172 LIVREE)** : documentation explicite de la visibilite PUBLIC du repo + justification technique (jamais documentee jusqu'ici -- Cor David S137a-ccdd). Le repo a ete cree PUBLIC des le depart (2026-08-31, PublicEvent GitHub audit). Justification : `secrets.env.age` est chiffre avec `age` (XChaCha20-Poly1305 + X25519, equivalent AES-256, incassable sans cle privee en Bitwarden 2FA), historique git clean verifie (aucun secret jamais commite en clair). Modele standard sops/git-crypt/ansible-vault/age. Aucun vecteur d'attaque ajoute vs un repo prive (les vecteurs reels -- compromission Bitwarden, vol fichier local dechiffre, malware -- existent des les deux cas). Cette visibilite PUBLIC **debloque** `bash <(curl -sSL https://raw.githubusercontent.com/DevDaveRug/dr-secrets/main/scripts/bootstrap-ccweb.sh)` sur les sessions CCWeb ephemeres (Codespace, container Claude Code Web) qui n'ont pas d'auth GitHub configuree. Ce qui est expose publiquement : la TAILLE du fichier chiffre (6508 octets, permet d'estimer "~30 variables") + la cle publique age (deja publique par design, voir ci-dessous). Ce qui reste protege : le contenu dechiffre (impossible sans cle privee).

## Cle publique (recipient)

```
age1r4flvl3zcxjz9dace842wym7dveaea3uqgk8p5afzeufj2q2rpssvrqpkr
```

## Cle privee

Fichier local **hors de ce repo**, hors de tout repo git :

```
C:\Users\conta\.config\age\keys.txt
```

**Sauvegardee dans Bitwarden vault** (note securisee `age keys.txt dr-secrets`, contenu integral des 3 lignes # created + # public key + AGE-SECRET-KEY-). **Validee bout en bout S136a-ccdd** via Test A (decrypt via cle locale) + Test B (decrypt via bw get notes).

## Helpers `scripts/`

Deux helpers canoniques pour obtenir un fichier `secrets.env` decrypte, quel que soit le systeme sous-jacent :

### PowerShell (`scripts/get-secrets.ps1`)

```powershell
$env_file = & "C:\Users\conta\dev\dr-secrets\scripts\get-secrets.ps1"
Get-Content $env_file | Where-Object { $_ -match "^SUPABASE_URL=" }
```

### Node (`scripts/get-secrets.mjs`)

```js
import { loadSecrets } from "C:/Users/conta/dev/dr-secrets/scripts/get-secrets.mjs";
const { path, env } = await loadSecrets();
console.log(env.SUPABASE_URL);
```

**Logique** :

- **Priorite 1** : si `C:\Users\conta\.cc-secrets\secrets.env` existe -> retourne-le (transitoire jusqu a S138).
- **Priorite 2** : si un temp frais (< 8h) existe dans `Documents\secrets-tmp.env` -> retourne-le.
- **Priorite 3** : reconstitue via `bw get notes | age -d` dans le temp, retourne-le.

Ainsi les scripts d appel ne changent pas quand le fichier local sera supprime : le helper bascule automatiquement.

## Dechiffrer manuellement (lecture directe)

Depuis CCDD ou PowerShell local (age installe) :

```powershell
age -d -i C:\Users\conta\.config\age\keys.txt secrets.env.age > secrets.env
```

Depuis CCWeb / Codespace / conteneur : copier temporairement la cle privee dans le conteneur (fichier ephemere), dechiffrer, puis effacer la cle.

Ou via BW en pipeline (nouveau S136a) :

```powershell
$env:BW_SESSION = (bw unlock --raw)
bw get notes "age keys.txt dr-secrets" --session $env:BW_SESSION | Out-File -Encoding utf8NoBOM tmp-key.txt
age -d -i tmp-key.txt secrets.env.age > secrets.env
Remove-Item tmp-key.txt
```

**Piege documente Test B S136a** : PowerShell capture `bw get notes` en `string[]` (tableau de lignes). Si tu passes ce tableau a `WriteAllText`, ca fait `.ToString()` = jointure par espace, et age -d echoue "no identities found". Fix : `-join "` + "`n" + `"` explicite. Deja gere dans les helpers.

## Rotation d'un secret

1. `git pull` (recupere la derniere version)
2. Dechiffrer -> `secrets.env` (fichier local, jamais commit)
3. Editer la ligne concernee
4. Rechiffrer : `age -e -r age1r4flvl3zcxjz9dace842wym7dveaea3uqgk8p5afzeufj2q2rpssvrqpkr -o secrets.env.age secrets.env`
5. `git commit -am "rotate <NOM>"` + `git push`
6. Effacer le `secrets.env` en clair local (`Remove-Item secrets.env`)

Voir aussi : `dr-context/docs/DR/DR_Professionnel/Pr_Outils/260817_PrOu_Protocole-Secrets.md` (v1.3.0) Section VII pour le pipeline `bw + age decrypt live` complet.

## Fichier local canonique

**Aujourd hui (transitoire S136a -> S138)** : `C:\Users\conta\.cc-secrets\secrets.env` reste source de verite en clair (voir memoire `reference-secrets-file`).

**Post-S138** : plus de fichier persistant en clair. La source de verite en clair vit uniquement dans le temp reconstitue par les helpers, efface en fin de session.

## Rappel securite

- Ne JAMAIS commit `secrets.env` en clair (couvert par `.gitignore`).

- Ne JAMAIS partager la cle privee `keys.txt`.

- Ce repo doit rester **prive**. Si visibilite bascule public : rotation immediate de TOUS les secrets.

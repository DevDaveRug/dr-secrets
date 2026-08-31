# dr-secrets — secrets chiffres age

Ce repo prive contient **le seul fichier** `secrets.env.age` : les secrets de David chiffres avec `age`, portables entre CCWeb, CCDD, PowerShell local et Codespace.

Correspond a **IDEE_infra_129** (Bootstrap secrets portable methode B) — voir `dr-context/docs/DR/DR_Professionnel/IDEAS_PRO.md`.

## Cle publique (recipient)

```
age1r4flvl3zcxjz9dace842wym7dveaea3uqgk8p5afzeufj2q2rpssvrqpkr
```

## Cle privee

Fichier local **hors de ce repo**, hors de tout repo git :

```
C:\Users\conta\.config\age\keys.txt
```

**A sauvegarder dans Bitwarden vault** (note securisee "age keys.txt dr-secrets"). Si le fichier est perdu, tous les secrets chiffres deviennent illisibles.

## Dechiffrer (lecture)

Depuis CCDD ou PowerShell local (age installe) :

```powershell
age -d -i C:\Users\conta\.config\age\keys.txt secrets.env.age > secrets.env
```

Depuis CCWeb / Codespace / conteneur : copier temporairement la cle privee dans le conteneur (fichier ephemere), dechiffrer, puis effacer la cle.

## Rotation d'un secret

1. `git pull` (recupere la derniere version)
2. Dechiffrer -> `secrets.env` (fichier local, jamais commit)
3. Editer la ligne concernee
4. Rechiffrer : `age -e -r age1r4flvl3zcxjz9dace842wym7dveaea3uqgk8p5afzeufj2q2rpssvrqpkr -o secrets.env.age secrets.env`
5. `git commit -am "rotate <NOM>"` + `git push`
6. Effacer le `secrets.env` en clair local (`Remove-Item secrets.env`)

## Fichier local canonique

La source de verite non chiffree reste `C:\Users\conta\.cc-secrets\secrets.env` sur la machine C:\DR (voir memoire `reference_secrets_file`). Ce repo est la copie chiffree portable.

## Rappel securite

-> Ne JAMAIS commit `secrets.env` en clair (couvert par `.gitignore`).

-> Ne JAMAIS partager la cle privee `keys.txt`.

-> Ce repo doit rester **prive**. Si visibilite bascule public : rotation immediate de TOUS les secrets.

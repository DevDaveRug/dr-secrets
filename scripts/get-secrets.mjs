#!/usr/bin/env node
// =============================================================================
// get-secrets.mjs -- Helper canonique pour obtenir secrets.env decrypte (Node)
// =============================================================================
// S136a-ccdd, IDEE_infra_149 livree.
//
// BUT : abstraire la source des secrets pour les scripts Node.
//
// STATUT S136a-ccdd -> S138 :
//   -> Aujourd hui : le fichier local C:\Users\conta\.cc-secrets\secrets.env
//      reste utilisable. Ce helper le retourne s il est present.
//   -> Post-S138 : le fichier local est supprime. Le helper reconstitue via
//      bw get notes | age -d.
//
// USAGE :
//   import { loadSecrets } from "C:/Users/conta/dev/dr-secrets/scripts/get-secrets.mjs";
//   const { path, env } = await loadSecrets();
//   process.env.SUPABASE_URL = env.SUPABASE_URL;  // etc.
//
// ou CLI :
//   node get-secrets.mjs        # affiche le chemin du fichier
//   node get-secrets.mjs purge  # supprime le temp
// =============================================================================

import { execSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const LOCAL_FILE  = "C:\\Users\\conta\\.cc-secrets\\secrets.env";
const TMP_FILE    = path.join(os.homedir(), "Documents", "secrets-tmp.env");
const SECRETS_AGE = "C:\\Users\\conta\\dev\\dr-secrets\\secrets.env.age";
const BW_ITEM     = "age keys.txt dr-secrets";

function parseEnv(content) {
  const env = {};
  for (const line of content.split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith("#")) continue;
    const i = t.indexOf("=");
    if (i < 0) continue;
    env[t.slice(0, i).trim()] = t.slice(i + 1).trim();
  }
  return env;
}

export async function loadSecrets({ forceRegen = false } = {}) {
  // Priorite 1 : local file (transitoire S136a -> S138)
  if (!forceRegen && fs.existsSync(LOCAL_FILE)) {
    return { path: LOCAL_FILE, env: parseEnv(fs.readFileSync(LOCAL_FILE, "utf8")) };
  }

  // Priorite 2 : temp frais (< 8h)
  if (!forceRegen && fs.existsSync(TMP_FILE)) {
    const ageMs = Date.now() - fs.statSync(TMP_FILE).mtimeMs;
    if (ageMs < 8 * 3600 * 1000) {
      return { path: TMP_FILE, env: parseEnv(fs.readFileSync(TMP_FILE, "utf8")) };
    }
  }

  // Priorite 3 : reconstitue via bw + age
  const bwSession = process.env.BW_SESSION;
  if (!bwSession) throw new Error("BW_SESSION absent. Fais 'bw unlock --raw' d abord et exporte le token.");

  const tmpKey = path.join(os.tmpdir(), "get-secrets-key.txt");

  const notes = execSync(`bw get notes "${BW_ITEM}" --session "${bwSession}"`, { encoding: "utf8" });
  fs.writeFileSync(tmpKey, notes.replace(/\r\n/g, "\n"), { encoding: "utf8" });

  try {
    const decrypted = execSync(`age -d -i "${tmpKey}" "${SECRETS_AGE}"`, { encoding: "utf8" });
    fs.writeFileSync(TMP_FILE, decrypted, { encoding: "utf8" });
    return { path: TMP_FILE, env: parseEnv(decrypted) };
  } finally {
    try { fs.unlinkSync(tmpKey); } catch {}
  }
}

// CLI
if (import.meta.url === `file://${process.argv[1].replace(/\\/g, "/")}`) {
  const cmd = process.argv[2] || "path";
  if (cmd === "purge") {
    try { fs.unlinkSync(TMP_FILE); console.log("purged"); } catch { console.log("nothing to purge"); }
  } else {
    const { path: p } = await loadSecrets();
    console.log(p);
  }
}

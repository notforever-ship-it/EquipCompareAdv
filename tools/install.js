// Copies the addon from this project into the game's AddOns folder, replacing only its own folder.
// The addon files live at the repo root (launchers expect the .toc there), so only the game's files
// are copied: the .toc and the Lua files. Development files stay behind.
// Usage: node tools/install.js [path to Interface\AddOns]

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const ADDON = "EquipCompareAdv";
const target = path.resolve(process.argv[2] || "E:\\Ravencraft\\twmoa_1181\\Interface\\AddOns");

if (!fs.existsSync(target)) {
  console.error(`AddOns folder not found: ${target}`);
  process.exit(1);
}
if (!fs.existsSync(path.join(ROOT, `${ADDON}.toc`))) {
  console.error(`${ADDON}.toc is missing from the project. Restore it with: git checkout -- .`);
  process.exit(1);
}

const entries = fs.readdirSync(ROOT, { withFileTypes: true }).filter((e) => {
  if (e.isDirectory()) return false;
  return e.name.endsWith(".lua") || e.name === `${ADDON}.toc`;
});

const dest = path.join(target, ADDON);
fs.rmSync(dest, { recursive: true, force: true });
fs.mkdirSync(dest, { recursive: true });
let count = 0;
for (const entry of entries) {
  const from = path.join(ROOT, entry.name);
  const to = path.join(dest, entry.name);
  fs.cpSync(from, to, { recursive: true });
  count += entry.isDirectory() ? fs.readdirSync(from).length : 1;
}

const version = (fs.readFileSync(path.join(dest, `${ADDON}.toc`), "utf8").match(/## Version:\s*(\S+)/) || [])[1];
console.log(`Installed ${ADDON} ${version} (${count} files) -> ${dest}`);

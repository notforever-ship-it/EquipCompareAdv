// Static checker for WoW 1.12.1 addon code (Lua 5.0), written for a PC with no Lua installed.
// - Tokenizes and fully parses the Lua 5.0 grammar (syntax errors fail the run).
// - Rejects 5.1+ syntax: '#', '%', '...' used as an expression, [=[ long brackets ]=].
// - Flags 5.1+/later-client library calls (string.match, select, ...).
// - Lists global names read but never defined by the addon or on the known-API list.
// Usage: node tools/check-lua.js [dir]   (default: the repo root, where the addon files live)

const fs = require("fs");
const path = require("path");

const KEYWORDS = new Set(("and break do else elseif end false for function if in local nil not or " +
  "repeat return then true until while").split(" "));

// Globals that exist in the 1.12.1 client (Lua 5.0 base libs + WoW API used by this addon).
const KNOWN_GLOBALS = new Set((
  // Lua 5.0 base
  "assert error ipairs pairs next pcall setmetatable getmetatable tonumber tostring type unpack " +
  "rawget rawset loadstring string table math date time getfenv setfenv collectgarbage gcinfo " +
  // WoW Lua aliases
  "tinsert tremove getn floor ceil abs max min mod format strlen strsub strfind strlower strupper gsub " +
  "getglobal setglobal " +
  // Script handler globals
  "this event arg1 arg2 arg3 arg4 arg5 arg6 arg7 arg8 arg9 " +
  // Frames and UI
  "CreateFrame UIParent Minimap GameTooltip DEFAULT_CHAT_FRAME UIErrorsFrame UISpecialFrames SlashCmdList " +
  "FauxScrollFrame_Update FauxScrollFrame_GetOffset FauxScrollFrame_OnVerticalScroll FauxScrollFrame_SetOffset " +
  "PlaySound GetCursorPosition IsShiftKeyDown IsControlKeyDown IsAltKeyDown " +
  "STANDARD_TEXT_FONT GameFontNormal GameFontNormalSmall GameFontNormalLarge GameFontHighlight GameFontHighlightSmall " +
  // Units, pets, world
  "UnitExists UnitName UnitLevel UnitCreatureFamily UnitCreatureType UnitIsUnit UnitClass UnitIsPlayer " +
  "UnitPlayerControlled UnitIsDead UnitClassification HasPetUI GetStablePetInfo GetPetLoyalty " +
  "GetRealmName GetZoneText GetRealZoneText GetTime UnitAffectingCombat " +
  // SuperWoW
  "UNKNOWNOBJECT PetRename " +
  "HasAction IsActionInRange GetActionTexture CheckInteractDistance UnitCanAttack GetPetHappiness UnitBuff " +
  "CastSpellByName WorldFrame " +
  "seterrorhandler geterrorhandler _ERRORMESSAGE debugstack GetNumAddOns GetAddOnInfo GetAddOnMetadata GetBuildInfo " +
  "UnitHealthMax UnitManaMax UnitAttackPower UnitDamage UnitAttackSpeed UnitArmor UnitStat GetSpellName " +
  "GetInventorySlotInfo GetInventoryItemCount PetAbandon ChatFontNormal " +
  "GetPetTrainingPoints GetNumTrainerServices GetTrainerServiceInfo GetTrainerServiceLevelReq " +
  "GetContainerItemInfo GetContainerItemLink GetContainerNumSlots GetPlayerBuff GetPlayerBuffTimeLeft " +
  "GetInventoryItemLink GetInventoryItemTexture UnitIsDeadOrGhost UnitOnTaxi GetPetExperience IsTradeskillTrainer UnitRangedDamage GetSpellCooldown GetSpellTexture UnitMana " +
  "SUPERWOW_VERSION " +
  // Equip Compare Adv: talents, the character window, chat link tooltips
  "GetNumTalentTabs GetNumTalents GetTalentInfo GetTalentTabInfo CharacterModelFrame ItemRefTooltip ShoppingTooltip1 GetDodgeChance GetParryChance"
).split(/\s+/).filter(Boolean));

// Member calls that don't exist in Lua 5.0 / the 1.12 client.
const BANNED_MEMBERS = {
  "string.match": "use string.find with captures",
  "string.gmatch": "use string.gfind",
  "table.unpack": "use unpack",
  "table.pack": "not in Lua 5.0",
  "table.wipe": "not in 1.12",
  "math.fmod": "use math.mod",
  "string.split": "not in 1.12",
};
const BANNED_GLOBALS = {
  select: "not in Lua 5.0 (use the implicit arg table)",
  strsplit: "not in 1.12",
  strtrim: "not in 1.12",
  wipe: "not in 1.12",
  print: "not in 1.12 (use DEFAULT_CHAT_FRAME:AddMessage)",
  hooksecurefunc: "not in 1.12",
  C_Timer: "retail only",
  goto: "not in Lua 5.0",
};

class LuaError extends Error {
  constructor(msg, line) { super(msg); this.line = line; }
}

function tokenize(src) {
  const toks = [];
  let i = 0, line = 1;
  const n = src.length;
  const push = (type, value, l) => toks.push({ type, value, line: l });
  const readLong = (start) => {
    // Lua 5.0 long bracket: [[ ... ]] with nesting
    let depth = 1, j = start + 2;
    const l0 = line;
    while (j < n) {
      if (src[j] === "\n") line++;
      if (src[j] === "[" && src[j + 1] === "[") { depth++; j += 2; continue; }
      if (src[j] === "]" && src[j + 1] === "]") { depth--; j += 2; if (depth === 0) return j; continue; }
      j++;
    }
    throw new LuaError("unfinished long string/comment", l0);
  };
  while (i < n) {
    const c = src[i];
    if (c === "\n") { line++; i++; continue; }
    if (c === " " || c === "\t" || c === "\r") { i++; continue; }
    if (c === "-" && src[i + 1] === "-") {
      if (src[i + 2] === "[" && src[i + 3] === "[") { i = readLong(i + 2); continue; }
      if (src[i + 2] === "[" && src[i + 3] === "=") throw new LuaError("[=[ long comment is Lua 5.1+", line);
      while (i < n && src[i] !== "\n") i++;
      continue;
    }
    if (c === "[" && src[i + 1] === "[") {
      const l0 = line; const end = readLong(i);
      push("string", src.slice(i + 2, end - 2), l0); i = end; continue;
    }
    if (c === "[" && src[i + 1] === "=") throw new LuaError("[=[ long string is Lua 5.1+", line);
    if (c === '"' || c === "'") {
      const l0 = line; let j = i + 1, val = "";
      while (true) {
        if (j >= n || src[j] === "\n") throw new LuaError("unfinished string", l0);
        if (src[j] === "\\") { val += src[j] + src[j + 1]; if (src[j + 1] === "\n") line++; j += 2; continue; }
        if (src[j] === c) break;
        val += src[j++];
      }
      push("string", val, l0); i = j + 1; continue;
    }
    if (/[0-9]/.test(c) || (c === "." && /[0-9]/.test(src[i + 1]))) {
      const m = src.slice(i).match(/^(0[xX][0-9a-fA-F]+|[0-9]*\.?[0-9]+([eE][+-]?[0-9]+)?)/);
      if (m[0].startsWith("0x") || m[0].startsWith("0X")) throw new LuaError("hex number literal is not reliable in Lua 5.0", line);
      push("number", m[0], line); i += m[0].length;
      if (/[A-Za-z_]/.test(src[i] || "")) throw new LuaError("malformed number", line);
      continue;
    }
    if (/[A-Za-z_]/.test(c)) {
      const m = src.slice(i).match(/^[A-Za-z_][A-Za-z0-9_]*/);
      push(KEYWORDS.has(m[0]) ? "kw" : "name", m[0], line); i += m[0].length; continue;
    }
    const three = src.substr(i, 3), two = src.substr(i, 2);
    if (three === "...") { push("op", "...", line); i += 3; continue; }
    if (["==", "~=", "<=", ">=", ".."].includes(two)) { push("op", two, line); i += 2; continue; }
    if (c === "#") throw new LuaError("'#' length operator is Lua 5.1+ (use table.getn / string.len)", line);
    if (c === "%") throw new LuaError("'%' operator is Lua 5.1+ (use math.mod)", line);
    if ("+-*/^<>=(){}[];:,.".includes(c)) { push("op", c, line); i++; continue; }
    throw new LuaError(`unexpected character '${c}'`, line);
  }
  push("eof", "<eof>", line);
  return toks;
}

class Parser {
  constructor(toks, file, report) {
    this.t = toks; this.p = 0; this.file = file; this.report = report;
    this.scopes = [new Set()];
    this.funcs = [{ vararg: true }];
  }
  get cur() { return this.t[this.p]; }
  peek(k = 1) { return this.t[this.p + k]; }
  is(type, value) { const c = this.cur; return c.type === type && (value === undefined || c.value === value); }
  isOp(v) { return this.is("op", v); }
  isKw(v) { return this.is("kw", v); }
  next() { return this.t[this.p++]; }
  expect(type, value) {
    if (!this.is(type, value)) {
      throw new LuaError(`expected '${value || type}' near '${this.cur.value}'`, this.cur.line);
    }
    return this.next();
  }
  expectMatch(value, opener, openLine) {
    if (!this.is("kw", value) && !this.is("op", value)) {
      const where = this.cur.line === openLine ? "" : ` (to close '${opener}' at line ${openLine})`;
      throw new LuaError(`expected '${value}'${where} near '${this.cur.value}'`, this.cur.line);
    }
    this.next();
  }
  pushScope() { this.scopes.push(new Set()); }
  popScope() { this.scopes.pop(); }
  declare(name) { this.scopes[this.scopes.length - 1].add(name); }
  isLocal(name) { for (let i = this.scopes.length - 1; i >= 0; i--) if (this.scopes[i].has(name)) return true; return false; }
  useGlobal(name, line, write) {
    if (this.isLocal(name)) return;
    if (BANNED_GLOBALS[name] && !write) this.report.warn(this.file, line, `'${name}': ${BANNED_GLOBALS[name]}`);
    (write ? this.report.globalWrites : this.report.globalReads).push({ name, file: this.file, line });
  }

  chunk() { this.block(); this.expect("eof"); }
  blockFollow() {
    const c = this.cur;
    return c.type === "eof" || (c.type === "kw" && ["else", "elseif", "end", "until"].includes(c.value));
  }
  block() {
    while (!this.blockFollow()) {
      if (this.isKw("return")) {
        this.next();
        if (!this.blockFollow() && !this.isOp(";")) this.explist();
        if (this.isOp(";")) this.next();
        if (!this.blockFollow()) throw new LuaError("'return' must be the last statement in a block", this.cur.line);
        return;
      }
      if (this.isKw("break")) {
        this.next();
        if (this.isOp(";")) this.next();
        if (!this.blockFollow()) throw new LuaError("'break' must be the last statement in a block", this.cur.line);
        return;
      }
      this.statement();
      if (this.isOp(";")) this.next();
    }
  }
  statement() {
    const c = this.cur;
    if (c.type === "kw") {
      switch (c.value) {
        case "do": { const l = this.next().line; this.pushScope(); this.block(); this.popScope(); this.expectMatch("end", "do", l); return; }
        case "while": { const l = this.next().line; this.exp(); this.expect("kw", "do"); this.pushScope(); this.block(); this.popScope(); this.expectMatch("end", "while", l); return; }
        case "repeat": { const l = this.next().line; this.pushScope(); this.block(); this.expectMatch("until", "repeat", l); this.exp(); this.popScope(); return; }
        case "if": {
          const l = this.next().line; this.exp(); this.expect("kw", "then"); this.pushScope(); this.block(); this.popScope();
          while (this.isKw("elseif")) { this.next(); this.exp(); this.expect("kw", "then"); this.pushScope(); this.block(); this.popScope(); }
          if (this.isKw("else")) { this.next(); this.pushScope(); this.block(); this.popScope(); }
          this.expectMatch("end", "if", l); return;
        }
        case "for": {
          const l = this.next().line;
          const names = [this.expect("name").value];
          if (this.isOp("=")) {
            this.next(); this.exp(); this.expect("op", ","); this.exp();
            if (this.isOp(",")) { this.next(); this.exp(); }
          } else {
            while (this.isOp(",")) { this.next(); names.push(this.expect("name").value); }
            this.expect("kw", "in"); this.explist();
          }
          this.expect("kw", "do"); this.pushScope(); names.forEach((nm) => this.declare(nm));
          this.block(); this.popScope(); this.expectMatch("end", "for", l); return;
        }
        case "function": {
          const l = this.next().line;
          const first = this.expect("name");
          let isMethod = false, dotted = false;
          while (this.isOp(".")) { this.next(); this.expect("name"); dotted = true; }
          if (this.isOp(":")) { this.next(); this.expect("name"); isMethod = true; }
          this.useGlobal(first.value, first.line, !dotted && !isMethod);
          this.funcbody(l, isMethod); return;
        }
        case "local": {
          this.next();
          if (this.isKw("function")) {
            const l = this.next().line; const nm = this.expect("name").value; this.declare(nm); this.funcbody(l, false); return;
          }
          const names = [this.expect("name").value];
          while (this.isOp(",")) { this.next(); names.push(this.expect("name").value); }
          if (this.isOp("=")) { this.next(); this.explist(); }
          names.forEach((nm) => this.declare(nm));
          return;
        }
      }
    }
    // exprstat: assignment or call
    const first = this.suffixedexp();
    if (this.isOp("=") || this.isOp(",")) {
      const targets = [first];
      while (this.isOp(",")) { this.next(); targets.push(this.suffixedexp()); }
      this.expect("op", "=");
      for (const tgt of targets) {
        if (tgt.kind === "call") throw new LuaError("cannot assign to a function call", tgt.line);
        if (tgt.kind === "name") this.useGlobal(tgt.name, tgt.line, true);
        if (tgt.kind === "paren") throw new LuaError("cannot assign to a parenthesized expression", tgt.line);
      }
      this.explist();
    } else {
      if (first.kind !== "call") throw new LuaError(`syntax error near '${this.cur.value}' (statement is not a call or assignment)`, this.cur.line);
    }
  }
  funcbody(line, isMethod) {
    this.expect("op", "(");
    this.pushScope();
    let vararg = false;
    if (isMethod) this.declare("self");
    if (!this.isOp(")")) {
      while (true) {
        if (this.isOp("...")) { this.next(); vararg = true; break; }
        this.declare(this.expect("name").value);
        if (!this.isOp(",")) break;
        this.next();
      }
    }
    this.expect("op", ")");
    if (vararg) this.declare("arg");
    this.funcs.push({ vararg });
    this.block();
    this.funcs.pop();
    this.popScope();
    this.expectMatch("end", "function", line);
  }
  explist() { this.exp(); while (this.isOp(",")) { this.next(); this.exp(); } }
  primaryexp() {
    const c = this.cur;
    if (c.type === "name") { this.next(); return { kind: "name", name: c.value, line: c.line, rootName: c.value }; }
    if (this.isOp("(")) { const l = this.next().line; this.exp(); this.expectMatch(")", "(", l); return { kind: "paren", line: l }; }
    throw new LuaError(`unexpected symbol near '${c.value}'`, c.line);
  }
  suffixedexp() {
    let e = this.primaryexp();
    const rootName = e.kind === "name" ? e.name : null;
    let member = rootName;
    let resolvedRoot = false;
    const resolveRoot = () => {
      if (!resolvedRoot && rootName) { this.useGlobal(rootName, e.line, false); resolvedRoot = true; }
    };
    while (true) {
      if (this.isOp(".")) {
        this.next(); const nm = this.expect("name").value;
        if (member) {
          member = member + "." + nm;
          if (BANNED_MEMBERS[member] && !this.isLocal(rootName)) this.report.warn(this.file, e.line, `'${member}': ${BANNED_MEMBERS[member]}`);
        }
        resolveRoot(); e = { kind: "index", line: e.line };
      } else if (this.isOp("[")) {
        resolveRoot(); member = null; const l = this.next().line; this.exp(); this.expectMatch("]", "[", l); e = { kind: "index", line: e.line };
      } else if (this.isOp(":")) {
        resolveRoot(); member = null; this.next(); this.expect("name"); this.callargs(); e = { kind: "call", line: e.line };
      } else if (this.isOp("(") || this.is("string") || this.isOp("{")) {
        if (this.isOp("(") && this.cur.line !== this.t[this.p - 1].line) {
          throw new LuaError("ambiguous syntax (function call x new statement): '(' on a new line", this.cur.line);
        }
        resolveRoot(); member = null; this.callargs(); e = { kind: "call", line: e.line };
      } else break;
    }
    if (e.kind === "name") return e; // bare name; caller decides read vs write
    return e;
  }
  callargs() {
    if (this.is("string")) { this.next(); return; }
    if (this.isOp("{")) { this.table(); return; }
    const l = this.expect("op", "(").line;
    if (!this.isOp(")")) this.explist();
    this.expectMatch(")", "(", l);
  }
  table() {
    const l = this.expect("op", "{").line;
    while (!this.isOp("}")) {
      if (this.isOp("[")) { const bl = this.next().line; this.exp(); this.expectMatch("]", "[", bl); this.expect("op", "="); this.exp(); }
      else if (this.is("name") && this.peek().type === "op" && this.peek().value === "=") { this.next(); this.next(); this.exp(); }
      else this.exp();
      if (this.isOp(",") || this.isOp(";")) this.next(); else break;
    }
    this.expectMatch("}", "{", l);
  }
  simpleexp() {
    const c = this.cur;
    if (c.type === "number" || c.type === "string") { this.next(); return; }
    if (c.type === "kw" && ["nil", "true", "false"].includes(c.value)) { this.next(); return; }
    if (this.isOp("...")) throw new LuaError("'...' as an expression is Lua 5.1+ (use the implicit 'arg' table)", c.line);
    if (this.isOp("{")) { this.table(); return; }
    if (this.isKw("function")) { const l = this.next().line; this.funcbody(l, false); return; }
    const e = this.suffixedexp();
    if (e.kind === "name") this.useGlobal(e.name, e.line, false);
  }
  exp(limit = 0) {
    const UNARY = 7;
    if (this.isKw("not") || this.isOp("-")) { this.next(); this.exp(UNARY); }
    else this.simpleexp();
    const PRI = { or: [1, 1], and: [2, 2], "<": [3, 3], ">": [3, 3], "<=": [3, 3], ">=": [3, 3], "~=": [3, 3], "==": [3, 3],
      "..": [5, 4], "+": [6, 6], "-": [6, 6], "*": [7, 7], "/": [7, 7], "^": [10, 9] };
    while (true) {
      const c = this.cur;
      const op = (c.type === "op" || c.type === "kw") ? PRI[c.value] : undefined;
      if (!op || op[0] <= limit) break;
      this.next();
      this.exp(op[1]);
    }
  }
}

function main() {
  const root = path.resolve(process.argv[2] || path.join(__dirname, ".."));
  const files = [];
  const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).forEach((e) => {
    const p = path.join(d, e.name);
    if (e.isDirectory()) {
      if (e.name === "tools" || e.name === ".git" || e.name === ".planning") return;
      walk(p);
    } else if (e.name.endsWith(".lua")) files.push(p);
  });
  walk(root);

  // TOC check: every .lua must be listed, every listed file must exist.
  const report = { errors: 0, warnings: 0, globalReads: [], globalWrites: [],
    warn(file, line, msg) { this.warnings++; console.log(`WARN  ${path.relative(root, file)}:${line}  ${msg}`); } };
  const tocs = fs.readdirSync(root).filter((f) => f.endsWith(".toc"));
  for (const toc of tocs) {
    const lines = fs.readFileSync(path.join(root, toc), "utf8").split(/\r?\n/);
    const listed = lines.map((l) => l.trim()).filter((l) => l && !l.startsWith("#"));
    for (const l of listed) {
      if (!fs.existsSync(path.join(root, l.replace(/\\/g, "/")))) { report.errors++; console.log(`ERROR ${toc}: listed file missing: ${l}`); }
    }
    for (const f of files) {
      const rel = path.relative(root, f);
      if (!listed.some((l) => path.normalize(l.replace(/\\/g, "/")) === path.normalize(rel))) {
        report.warn(path.join(root, toc), 0, `${rel} is not listed in the TOC`);
      }
    }
    if (!lines.some((l) => /^##\s*Interface:\s*11200\s*$/.test(l))) { report.errors++; console.log(`ERROR ${toc}: missing '## Interface: 11200'`); }
  }

  for (const f of files) {
    const src = fs.readFileSync(f, "utf8");
    try {
      const parser = new Parser(tokenize(src), f, report);
      parser.chunk();
    } catch (e) {
      if (!(e instanceof LuaError)) throw e;
      report.errors++;
      console.log(`ERROR ${path.relative(root, f)}:${e.line}  ${e.message}`);
    }
  }

  const defined = new Set(report.globalWrites.map((g) => g.name));
  const unknown = {};
  for (const g of report.globalReads) {
    if (defined.has(g.name) || KNOWN_GLOBALS.has(g.name)) continue;
    (unknown[g.name] = unknown[g.name] || []).push(`${path.relative(root, g.file)}:${g.line}`);
  }
  const unknownNames = Object.keys(unknown).sort();
  for (const nm of unknownNames) {
    report.warn(root, 0, `unknown global '${nm}' used at ${unknown[nm].slice(0, 4).join(", ")}${unknown[nm].length > 4 ? " ..." : ""}`);
  }
  const addonGlobals = [...defined].sort();
  console.log(`\nGlobals defined by the addon (${addonGlobals.length}): ${addonGlobals.join(", ")}`);
  console.log(`Checked ${files.length} files: ${report.errors} error(s), ${report.warnings} warning(s)`);
  process.exit(report.errors ? 1 : 0);
}

main();

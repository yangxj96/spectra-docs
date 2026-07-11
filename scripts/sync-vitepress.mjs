/**
 * Obsidian → VitePress 文档同步脚本
 *
 * 将 spectra/docs/ 下的 Obsidian 笔记转换为 VitePress 格式，
 * 输出到 yangxj96-website/docs/pages/spectra-admin/ 目录。
 *
 * 用法：node scripts/sync-vitepress.mjs
 */

import { readFileSync, writeFileSync, readdirSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

// === 配置 ===

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const DOCS_DIR = resolve(ROOT, "docs");
/** VitePress 网站源码路径 */
const TARGET_DIR = resolve(ROOT, "../yangxj96/yangxj96-website/docs/pages/spectra-admin");

// === 读取映射配置 ===

const mappingPath = resolve(__dirname, "vitepress-mapping.json");
const mappings = JSON.parse(readFileSync(mappingPath, "utf-8"));

/**
 * 将 Obsidian [[wikilink]] 转为纯文本
 *
 * [[笔记名]]           → 笔记名
 * [[笔记名|显示文字]]   → 显示文字
 * [[笔记名#锚点]]       → 笔记名
 */
function convertWikilinks(content) {
    return content.replace(/\[\[([^\]|]+?)(?:\|(.+?))?\]\]/g, (_, target, display) => {
        // 去掉可能的 #锚点
        const name = display || target.split("#")[0];
        return name;
    });
}

/**
 * 去掉"相关笔记"章节
 * 因为 VitePress 站点里没有对应的笔记页面
 */
function stripRelatedNotes(content) {
    const lines = content.split("\n");
    const result = [];
    let inRelatedSection = false;

    for (const line of lines) {
        if (/^## 相关笔记/.test(line)) {
            inRelatedSection = true;
            continue;
        }
        if (inRelatedSection) {
            // 遇到下一个 ## 标题，退出相关笔记区域
            if (/^## /.test(line)) {
                inRelatedSection = false;
                result.push(line);
            }
            continue;
        }
        result.push(line);
    }

    return result.join("\n");
}

/**
 * 提取第一个 # 标题作为 title
 */
function extractTitle(content) {
    const match = content.match(/^# (.+)$/m);
    return match ? match[1].trim() : null;
}

/**
 * 转换 frontmatter：去掉 tags，添加 layout: doc
 */
function convertFrontmatter(content, title) {
    let lines = content.split("\n");

    // 检查是否有 frontmatter
    if (lines[0] === "---") {
        const endIdx = lines.indexOf("---", 1);
        if (endIdx > 0) {
            const fmLines = [];
            // 如果有显式 title，添加它
            if (title) {
                fmLines.push("---");
                fmLines.push("layout: doc");
                fmLines.push(`title: ${title}`);
                fmLines.push("---");
            } else {
                fmLines.push("---");
                fmLines.push("layout: doc");
                fmLines.push("---");
            }
            // 拼接：新的 frontmatter + 剩余内容
            const rest = lines.slice(endIdx + 1);
            return [...fmLines, ...rest].join("\n");
        }
    }

    // 没有 frontmatter 时，插入新的
    if (title) {
        return ["---", "layout: doc", `title: ${title}`, "---", "", ...lines].join("\n");
    }
    return ["---", "layout: doc", "---", "", ...lines].join("\n");
}

/**
 * 转换单篇笔记
 */
function convertNote(mapping) {
    const sourcePath = resolve(DOCS_DIR, mapping.source);

    let content;
    try {
        content = readFileSync(sourcePath, "utf-8");
    } catch (err) {
        console.error(`  ❌ 无法读取源文件: ${mapping.source}`);
        return false;
    }

    // 提取标题
    const title = extractTitle(content);

    // 转换内容
    content = convertWikilinks(content);
    content = stripRelatedNotes(content);
    content = convertFrontmatter(content, title);

    // 写入目标
    const targetPath = resolve(TARGET_DIR, mapping.target);
    writeFileSync(targetPath, content, "utf-8");

    console.log(`  ✅ ${mapping.source} → ${mapping.target}`);
    return true;
}

// === 主流程 ===

console.log("📦 Obsidian → VitePress 文档同步\n");
console.log(`源目录: ${DOCS_DIR}`);
console.log(`目标目录: ${TARGET_DIR}\n`);

let synced = 0;
let failed = 0;

for (const mapping of mappings) {
    console.log(`[${mapping.group}]`);
    if (convertNote(mapping)) synced++;
    else failed++;
}

console.log(`\n✨ 完成: ${synced} 篇成功${failed > 0 ? `, ${failed} 篇失败` : ""}`);
if (failed > 0) process.exit(1);

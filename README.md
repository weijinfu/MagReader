# MagReader

MagReader 是一个本地优先、单用户的英文外刊阅读与英语学习工具。它支持 RSS 拉取英文文章、正文阅读、句子/单词选择、翻译解释、发音、生词和原句保存、复习队列、深色模式和阅读排版调整。

## 功能概览

- RSS feed 管理：添加、删除、手动刷新 RSS 源，文章自动去重入库。
- 阅读器：文章列表、正文阅读、字体/字号/行距/宽度调整、深色模式、图片宽度约束。
- 选择交互：单击句子高亮整句，双击单词高亮单词，拖选短语或句子保留手动选择。
- 学习工具：翻译、句子解释、长难句结构拆解、词组提示、难度评估。
- 保存与复习：保存单词、保存原句、按状态筛选/排序/展开详情、删除本地记录、Review 队列。
- 发音：使用浏览器 Web Speech API 朗读单词、句子和标题。
- 导出：支持导出已保存的单词和句子。

## 技术栈

- Next.js 15 + React 19 + TypeScript
- SQLite + better-sqlite3
- rss-parser + Mozilla Readability + jsdom
- Vitest + ESLint
- Google Translate public endpoint用于翻译；AI 分析部分目前是本地 mock 逻辑，接口已封装，后续可替换为 OpenAI 或其他 provider。

## 环境要求

- Node.js 20 或更新版本
- npm
- macOS / Linux / Windows 均可运行；当前项目主要在 macOS 本地验证
- 可选：网络访问，用于 RSS 拉取、文章正文抽取和 Google Translate

## 安装

```bash
npm install
```

项目默认使用本地 SQLite 数据库。首次访问应用或运行初始化脚本时会自动创建数据库和表结构。

```bash
npm run db:init
```

默认数据库路径：

```text
data/magreader.db
```

如需改用其他数据库文件：

```bash
MAGREADER_DB=/absolute/path/magreader.db npm run dev
```

## 开发启动

```bash
npm run dev
```

默认绑定：

```text
http://127.0.0.1:3000
```

如果 `3000` 已被占用，Next.js 会自动使用下一个可用端口，例如：

```text
http://127.0.0.1:3001
```

终端会显示实际可访问地址。

## 生产构建与运行

```bash
npm run build
npm run start
```

`start` 同样绑定到 `127.0.0.1`。生产运行前请先执行 `npm run build`。

## 常用命令

```bash
npm run dev         # 启动开发服务器
npm run build       # 生产构建
npm run start       # 启动生产服务器
npm run lint        # ESLint 检查
npm run typecheck   # TypeScript 类型检查
npm test            # 运行测试
npm run test:watch  # 监听模式运行测试
npm run db:init     # 初始化本地数据库
```

## 使用方法

### 1. 添加 RSS 源

1. 打开应用。
2. 进入 `Feeds`。
3. 输入 RSS 地址。
4. 点击添加后，再点击 `Refresh RSS` 拉取文章。

可以使用任意公开 RSS 地址。若站点限制正文抓取，MagReader 会退回使用 RSS 摘要。

### 2. 阅读文章

1. 在 `Articles` 中选择一篇文章。
2. 使用顶部搜索框筛选文章。
3. 使用 `Hide list` / `Show list` 收起或展开文章列表。
4. 使用 `Dark` / `Light` 切换主题。
5. 使用 `A-` / `A+` 调整字号。

正文图片会自动限制在阅读区域内，不会横向撑出页面。

### 3. 选择、翻译和解释

- 单击正文句子：选中并高亮整句。
- 双击英文单词：选中并高亮单词。
- 拖选文本：保留手动选择，适合短语、半句或特殊片段。
- 点击悬浮工具条：
  - `Translate`：翻译并生成学习分析。
  - `Speak`：朗读选中文本。
  - `Save`：自动按单词/句子保存。
  - `More`：跳转到右侧 Learning Panel。

悬浮工具条和高亮不会随时间自动消失。它们会在点击正文外、按 `Esc`、切换文章/页面或选择新文本时清除。

### 4. 保存单词和句子

在右侧 Learning Panel 或悬浮工具条中保存内容：

- 单词会保存原词、翻译、解释、来源句和保存次数。
- 句子会保存原句、翻译、解释和来源文章。
- 保存前若尚未分析，系统会先分析再保存。

### 5. 管理 Saved Words / Sentences

进入 `Saved Words` 或 `Sentences` 后可以：

- 按熟悉度筛选。
- 按来源筛选。
- 按更新时间、创建时间、保存次数、字母顺序或句子长度排序。
- 展开详情查看解释、来源句、来源文章和时间。
- 朗读条目。
- 调整复习状态：`new`、`learning`、`familiar`、`mastered`。
- 删除本地记录。删除会弹出确认框，确认后为硬删除。

### 6. Review 复习

进入 `Review`：

- 默认只显示未 mastered 的内容。
- 可以筛选 `All`、`Words`、`Sentences`。
- 可以按 `new`、`learning`、`familiar` 筛选。
- 复习卡默认隐藏答案，点击展开后查看翻译和解释。
- 可以朗读、推进状态或删除条目。

### 7. 导出

点击顶部 `Export` 可导出保存内容。当前默认导出 CSV：

```text
/api/export?format=csv
```

也支持 JSON：

```text
/api/export?format=json
```

## 数据与隐私

- 应用是本地优先、单用户设计。
- 数据默认保存在 `data/magreader.db`。
- `.gitignore` 已排除本地数据库、构建产物、node_modules 和浏览器验证截图。
- 当前没有登录、云同步或多用户权限系统。
- 翻译请求会把选中文本发送到 Google Translate public endpoint；mock AI 分析在本地完成。

## 常见问题

### 端口不是 3000

如果终端显示：

```text
Port 3000 is in use, using available port 3001 instead.
```

请使用终端实际显示的地址访问，例如 `http://127.0.0.1:3001`。

### RSS 刷新失败

常见原因：

- RSS 地址不可访问。
- 网络连接失败。
- 来源站点阻止正文抓取。
- 文章正文太短，系统自动退回 RSS 摘要。

可以在 `Feeds` 页面查看错误信息，并尝试手动刷新。

### 翻译失败

翻译依赖网络访问 Google Translate public endpoint。若网络不可用或请求被限制，Learning Panel 会显示失败状态。可以稍后重试。

### 浏览器发音没有声音

发音依赖浏览器 Web Speech API。请检查：

- 浏览器是否支持 speech synthesis。
- 系统是否有可用英文语音。
- 系统音量是否开启。

### 数据库需要重置

停止应用后删除本地数据库文件，再重新初始化：

```bash
rm data/magreader.db data/magreader.db-shm data/magreader.db-wal
npm run db:init
```

这会永久删除本地文章、保存词句和设置。执行前请确认已经备份需要的数据。

## 开发说明

主要目录：

```text
app/                  Next.js App Router 页面和 API routes
components/           主应用 UI
lib/                  数据库、RSS、AI/翻译、工具函数
scripts/              初始化脚本
tests/                Vitest 测试
data/                 本地 SQLite 数据库，默认不提交
```

核心接口：

- `/api/dashboard`：读取 feeds、articles、saved words、saved sentences、settings。
- `/api/feeds`：添加/删除 RSS。
- `/api/feeds/refresh`：手动刷新 RSS。
- `/api/ai`：翻译和学习分析。
- `/api/words`：保存、更新状态、删除单词。
- `/api/sentences`：保存、更新状态、删除句子。
- `/api/settings`：保存主题和阅读设置。
- `/api/export`：导出 CSV/JSON。

## 验证状态

当前项目已通过：

```bash
npm run typecheck
npm run lint
npm test
npm run build
```

构建时可能会出现一个非致命提示：当前项目使用自定义 ESLint flat config，Next.js 会提示未检测到 Next ESLint plugin。这不影响构建结果。

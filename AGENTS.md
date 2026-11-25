# NVLITE 项目约定

这是 NVLITE 的唯一工作目录，既是开发目录也是 git 仓库。
在 `/home/bdd669/nvlite` 启动 pi 就是本项目的会话。

## 项目是什么

Windows 批处理脚本，把 NVIDIA 官方驱动包拆开，只解压白名单里的条目，
丢掉 NVIDIA App、遥测、更新器，得到一个精简的安装源。它不装驱动。

## 改代码前必读的四条

这四条是踩出来的，违反任何一条都会静默出问题：

1. **全程不用延迟展开**。所有变量 `%VAR%`，开头 `setlocal DisableDelayedExpansion`。
   所以括号块内不能"赋值后立刻读自己刚写的值"。
2. **括号块内不出现裸的 echo 路径变量**。路径含右括号会截断块。
3. **`rem` 注释里不写尖括号、竖线、和号**。
4. **删除逻辑必须内联**，不能提取成 `call :sub`（实测静默失效）。

还有一条：**`for` 的 DO 子句只解析一次**，循环里 `set "MISS=%MISS% x"` 会覆盖而不是追加，
必须一行一个 `if`。

## 编码

源文件 **GBK + CRLF**。UTF-8 会让中文乱码，LF 会让 goto 标签和 if 块解析异常。
`.gitattributes` 已固定 `*.bat text eol=crlf`。

## 禁止

- 不要往 `DROP` / `DROPDIR` 里填内容。删 `Display.Driver` 内部文件会导致安装失败
  （实测 `NvCamera`，装到"系统"检查就报"所需文件丢失"）。
- 不要为了减行数把校验代码压进 `for`。上一版这么做埋了两个静默失效 bug。
- 不要凭文件名推断组件用途就建议删除。`nvxdapix.dll` 差点被当成"DX 兼容层"删掉，
  实际是控制面板组件。

## 验证要求

改了脚本必须真机跑一遍。**生成成功 ≠ 能装上**，`NvCamera` 那次就是生成完全正常、
装到一半才失败。生成后至少走一次完整安装。

## 发布

```bash
git add -A && git commit -m "..." && git push origin main
```

推送如果报 `GnuTLS recv error (-110)`，是这台机器的 TLS 问题，已经配好：
`http.version=HTTP/1.1`、`http.postBuffer=524288000`。重试即可。

发布 release 用 `gh release create`，附 `.bat` 和 `.zip`。

## 目录结构

仓库里的文件（会被提交）：

```
NVLITE.bat              主程序，无版本号后缀，内容 = 最新的 NVLITE_vN.N.bat
README.md               中文，GitHub 默认显示
README.en.md            英文
DISCLAIMER.md           AI 声明，改测试范围时更新
LICENSE                 MIT
AGENTS.md               本文件，给 AI 会话看的约定
HANDOFF.md              交接文档，给下一个会话看
docs/technical-notes-zh.md   技术细节和所有踩过的坑
```

本地保留但不提交（`.gitignore` 已排除）：

```
归档/                   历史版本 NVLITE_v*.bat 和 zip
实测样本/               真机测试产物，含本机路径
项目说明.md             内部演进记录，已并入 docs/
NVLITE_使用说明.txt     内容与 README 重复
```

发布新版本时：改 `NVLITE.bat`，把带版本号的副本丢进 `归档/`，同步文档，commit。

## 文档

- `README.md` 中文（默认显示）、`README.en.md` 英文，两个要同步改
- `DISCLAIMER.md` AI 声明，改测试范围时更新
- `docs/technical-notes-zh.md` 技术细节和所有踩过的坑

## 交接详情

当前状态、待办、历史决策见 [`HANDOFF.md`](HANDOFF.md)。

# NVLITE v2.0

## 它是什么

从 NVIDIA 官方驱动包（7-Zip SFX）里只提取白名单条目，丢掉捆绑软件、遥测、
更新器、游戏滤镜，得到一个干净的小体积安装源。

**核心就是一条 7z 命令**（第 7 步），其余是输入校验和安全保护。

## 版本演进

| 版本 | 行数 | 说明 |
|---|---|---|
| 原始 NV驱动精简.bat | 67 | 只认 7-Zip，双击闪退，出错无提示 |
| v1.0.2 | 300 | 功能堆多了，其中"删老系统目录"占 65 行但对 621.24 是空操作 |
| **v2.0** | **181** | 砍掉空操作和过度设计，回到"一条命令 + 必要校验" |

v2.0 砍掉的：删老系统目录（实测匹配 0 个）、体积统计、三个计数器、
NVI2 DLL 检查、setup.cfg 比例检查。
保留的：多解压器支持、防误删标记、setup.cfg 空文件保护、静默脚本、版本号。

## 目录

| 路径 | 内容 |
|---|---|
| `NVLITE_v2.0.bat` | 主程序 |
| `NVLITE_使用说明.txt` | 给使用者看的 |
| `实测样本/` | 621.24 桌面版真机产物 |
| `归档/` | 历史版本 |

## 技术要点

- 编码 **GBK + CRLF**。用 UTF-8 保存会导致中文全乱码。
- 取输入阶段 `disabledelayedexpansion`（防路径含 `!`），之后开启。
- 括号块内的 `echo` 用 `!VAR!` 且路径加引号。
- `rem` 注释里不写 `<` `>` `|` `&`。
- 删除逻辑必须内联，不用 `call :sub`（实测会静默失效）。

## 已验证（621.24 桌面版，2026-11-22）

- 生成、安装、驱动生效全部正常
- PhysX 9.26.0904 / HD 音频 1.4.6.6 / 图形驱动 621.24 均"已安装"
- 解压器 NanaZipC.exe（Store 版）正常
- 产物 3.13GB；`setup.cfg` 过滤后 77694 字节（原 89361）

## 待验证

- v2.0 尚未真机运行
- Bandizip `bz.exe` 能否解开 NVIDIA 的 SFX 包
- 笔记本包（NVPCF / Optimus 缺失后动态加速是否受影响）

## 踩过的坑

| 坑 | 后果 | 结论 |
|---|---|---|
| `rem` 写 `<` `>` `&` | cmd 当重定向/分隔符 | 注释里不写 |
| 删除循环改成 `call :sub` | 删除数从 312 变 0，静默失效 | 保持内联 |
| 子程序用 `!LOG!` 写日志 | 日志 0 条记录 | 用 `%LOG%` |
| 把 7z 的 `Size:` 当提取结果 | 误以为删目录省了 670MB | 那是整包大小 |
| `rd /q /s` 无条件删输出目录 | 会误删用户同名目录 | 用 `nvlite_log.txt` 作标记 |
| 加 NVI2 DLL 硬检查 | 各版本层级不同，误报会让包完全不能用 | 降级或删除 |
| 只在静态检查后就交付 | call 版失效，屏幕看不出 | 每次必须真机跑 |

## v2.0.2

| 改动 | 原因 |
|---|---|
| 静默脚本加 `chcp 65001` | 装在含中文的路径下可能失败（DeepSeek 审查指出） |
| 静默脚本内补 NVI2 存在性检查 | 目录错位时提前警告 |
| setup.cfg 注释更正 | 新驱动 XML 里 `EULAandPrivacyPolicyText` 含 `EulaHtmlFile` 子串，过滤确实删内容，非空转 |

## 审核记录（DeepSeek 子代理）
- 只读审查，未实际执行
- 主程序逻辑通过，三处建议（UTF-8 / NVI2 检查 / 文档更新）全部采纳

## 判断驱动包版本的坑（2026-11-25）

`setup.cfg` 里的 `<setup version="621.24">` **不代表驱动包版本**。
实测 621.40 的 setup.cfg 与 621.24 的字节完全相同（md5 `725aabc2...`），
NVIDIA 没更新这个属性。

**正确判断方式**：看文件名、看 md5、看字节数，不要看 `version` 属性。

## 621.40 与 621.24 的差异（实测）

| 文件 | 字节 | 是否变化 |
|---|---|---|
| setup.cfg | 77694（过滤后）/ 89361（原始） | md5 相同，**未变** |
| ListDevices.txt | 424667 | 与 621.24 一致 |
| EULA.txt | 46006 | 与 621.24 一致 |

结论：过滤逻辑对 621.40 同样适用，无需重新验证。

## v3.0（更激进精简）

| 项目 | v2.0.3 | v3.0 |
|---|---|---|
| 总行数 | 187 | **165** |
| 有效代码行 | ~140 | **123** |
| 新增精简 | — | 删 `nvdrsdb0/1.bin`（控制面板 3D 预设库） |
| 可配置项 | 1 个（EXTRA） | 3 个（REQ / EXTRA / DROP） |

**不能删的东西（有实证）**：
- `nvxdapix.dll` → 删了 NVDisplay.Container.exe 会崩溃、控制面板打不开
  （NVIDIA 官方论坛多帖证实）
- `nvlddmkm.sys` → 驱动核心
- `.inf` 文件 → 按 GPU 型号匹配硬件，删错就装不上

## 为什么"更激进精简组件"空间有限

Display.Driver 里占空间的主体是驱动核心和按型号分的 INF，
这两类都动不得。剩下能安全删的只有预设数据库这类小文件。
真正的体积收益来自"不提取"（NVIDIA App / NvContainer / Ansel 等），
这部分在 v1.0 时代就已经做完了。

## v3.1

**重大发现（621.40 实测日志）**：`Display.Driver` 内部还藏着这些子目录，
即使顶层白名单里排除了 NvContainer/NvCamera，它们的内容仍被打包在驱动目录里。

```
Display.NvContainer   控制面板后台服务（不能删）
ngx-builtins          DLSS 依赖（不能删）
NvCamera              Ansel 截图（可删）
NVCPL                 控制面板本体（不能删）
NVWMI                 WMI 监控接口（可删，影响监控软件）
```

v3.1 新增 `DROPDIR` 配置，默认删 `NvCamera`。

**输出精简**：完成页从 20 行压到 9 行，向原始脚本的简洁风格靠拢。

## v3.1.1

**实测发现**：`nvdrsdb0.bin` / `nvdrsdb1.bin` 不在 `Display.Driver` 根目录，
v3.1 的根目录检查删不到（日志只报"移除 1 项"，实际只删了 NvCamera）。

改用 `dir /s /b` 递归查找，各版本放哪都能找到。找不到就跳过，不报错。

**验证方法**：跑完看日志
- 有 `[TRIM] ...\nvdrsdb0.bin` → 找到了并删除
- 没有 `[TRIM]` 行 → 这个驱动包不含这两个文件（新版可能已移除），属正常

## v4.0（重构版）

**重构原则：全程禁用延迟展开**。所有变量用 `%VAR%`，用 `goto/标签` 代替大括号块。
这样彻底避开 `!VAR!` 被路径里的感叹号吃掉、以及块内预展开读不到新值这两类坑。

### 修掉的 4 个真 bug

| # | 问题 | 后果 | 修法 |
|---|---|---|---|
| 1 | **版本号提取失效** | 输出目录变成 `621.40-desktop-win10-win11-64bit-international-nsd-dch-whql-Desktop-Win11` | `findstr /b` 匹配的是行首，永远不命中。改回直接 `for /f "delims=-"` |
| 2 | **`for` 里累加 `%MISS%` 会覆盖** | 多个文件缺失时只报最后一个 | `for` 的 DO 子句只解析一次，改为一行一个 `if` |
| 3 | 块内裸 `%OUT%` | 路径含右括号会截断块 | 改成 `goto` 结构或加引号 |
| 4 | `set P=%P:"=%` 无外层引号 | 粘贴含 `&` 的路径会被当命令分隔符 | 加回外层引号 |

### 行数变化

| 版本 | 行数 | 说明 |
|---|---|---|
| v3.1.1 | 178 | 含 2 个静默失效的 bug |
| **v4.0** | **220** | 多了 42 行，全是独立的 `if` 检查和 `goto` 结构 |

**这 42 行不是退化**：用 `for` 一行能写完但会静默失效，用 `if` 一行一个虽然长但正确。
上一轮追求行数少（300→165）时，正是把校验代码压进 `for` 才埋下的 bug。

### 已知限制

- 驱动包路径**不能含左右圆括号**（`for /f in ('dir ...')` 的命令里括号会被误判）。路径含空格、中文、和号、感叹号都没问题。
- 删除逻辑必须内联，不能提取成 `call :sub`（实测静默失效）。

## v4.1

**实测结论（621.40）**：驱动包里已不含 `nvdrsdb0.bin` / `nvdrsdb1.bin`。
v4.0 日志里没有任何 `[TRIM]` 行，`[精简]` 只报 1 项（NvCamera），证实这一点。
所以把 `DROP` 默认清空，避免配置与实际不符。

**顺带修掉清空后引入的语法错误**：`for %%F in ()` 在 cmd 里会报错，
给 `DROP` 和 `DROPDIR` 都加了 `if not defined ... goto` 守卫。

### 最终精简能力（621.40 实测）

Display.Driver 下只有 4 个目录：

| 目录 | 状态 |
|---|---|
| NvCamera | ✅ 默认删除 |
| NVWMI | ⚠️ 可删，影响 HWiNFO 之类监控软件 |
| Display.NvContainer | ❌ 控制面板后台服务 |
| NVCPL | ❌ 控制面板本体 |
| ngx-builtins | ❌ DLSS 依赖 |

**精简已到极限**。真正的体积收益来自"只提取白名单"，这个从 v1.0 就做到了。

## v4.1 真机验证通过（2026-11-25 16:52，621.40）

```
[NVLITE v4.1] 2026/11/25 周三 16:52:27.40
[ZIP] NanaZipC.exe (模式 7z)
[DROP]  / NvCamera
Everything is Ok
[TRIMDIR] NvCamera
[LIST] Display.Driver 下的子目录:
   Display.NvContainer
   ngx-builtins
   NVCPL
   NVWMI
[精简] 额外移除 1 项
[OK] 已生成 Install_Silent.bat
保存路径: C:\Users\<user>\Downloads\621.40-Desktop-Win11
```

**逐项核对**：
- 版本号提取正确（`621.40-Desktop-Win11`，不再是完整文件名）✅
- `DROP` 为空时没有触发 `for %%F in ()` 语法错误 ✅
- `NvCamera` 删除生效，LIST 只剩 4 项 ✅
- 静默脚本生成成功 ✅

**结论：脚本功能全部验证通过，进入收尾。**

## 调研结论：Display.Driver 内部不能再删任何东西

查询来源：
- [PCGamingWiki Nvidia 条目](https://www.pcgamingwiki.com/wiki/Nvidia)：Ansel 包含在常规显示驱动包里，官方推荐用 `NvCameraConfiguration` **禁用**，不是删文件
- [NVIDIA NVWMI 官方页](https://www.nvidia.com/en-us/drivers/nvwmi/2_33/nvwmi-win10-win8-win7-x64-2-33-driver)：NVWMI 是给 IT 管理员/Quadro 的 WMI 接口
- [TechPowerUp NVCleanstall](https://www.techpowerup.com/nvcleanstall)：走**组件级**删除，不是删驱动内部文件

| 目录 | 作用 | 结论 |
|---|---|---|
| NvCamera | Ansel 截图 | ❌ 实测删除导致安装失败 |
| NVCPL | 控制面板本体 | ❌ |
| Display.NvContainer | 控制面板后台服务 | ❌ |
| ngx-builtins | DLSS 依赖 | ❌ |
| NVWMI | IT 管理 WMI 接口 | ⚠️ 能装但监控软件读不到显卡温度 |

**唯一有效的精简手段是 `EXTRA` 白名单**（PhysX ~50MB / HDAudio ~20MB）。
这是组件级，等价于 NVCleanstall 的做法，已有实测依据。

### 教训

`DROPDIR` / `DROP` 两个变量保留但默认清空，并写明为什么不能用。
以后想加，必须先在真机上装一遍验证，不能凭"这组件应该没用"就删。

## v4.3（稳定性加固）

深度审查（3 个子代理，deepseek 模型）发现并修复 4 个问题：

| # | 问题 | 修法 |
|---|---|---|
| F1 | `setlocal` 会继承外部延迟展开状态 | 显式 `setlocal DisableDelayedExpansion` |
| F2 | 错误分支里裸 `%P%` | 路径含 `)` 或 `&` 会截断块，加引号 |
| F3 | `rd` 删标记文件后导致误判 | 加 `Display.Driver\` 作备用判据 |
| F4 | `move` 覆盖 setup.cfg 失败时静默 | 加显式警告 |
| 顺 | `set /a TRIM+=1` 会回显数字 | 加重定向到 nul |
| 顺 | `if not defined VER` 永不触发 | 删掉死代码 |

**保留未改**（有实证的安全边界）：
- `for /f` 没开 `usebackq`，路径含 `&` 时 IN 子句会有问题 —— 但这是已知限制，已写在注释里
- `where` 返回多路径时 `Z` 变量可能带换行 —— 实测不影响（同一个 NanaZipC 只在 PATH 里出现一次）

## 修正一个错误判断（2026-11-25）

之前一直写"推荐用 Install_Silent.bat，因为过滤 setup.cfg 会让许可页残缺"。
**这是错的推测。**

用户实测：621.24 和 621.40 都是**双击 Setup.exe** 装成功的，
过滤掉那 79 行 EULA 声明并不影响手动安装流程。

`Install_Silent.bat` 的价值只是"不用点下一步"，不是"能不能装成"。
文档已改成"两种都行"。

A/B 对比确认 NvCamera 才是 v4.1 失败的原因：

| 版本 | 删 NvCamera | 安装方式 | 结果 |
|---|---|---|---|
| v4.1 | 是 | Setup.exe | 所需文件丢失 |
| v4.2 | 否 | Setup.exe | 成功 |

## v4.4（解压器支持扩展）

之前只认 NanaZipC / 7z / 7za / 7zz / bz，而且 PATH 查找漏了 7za/7zz。
现在重写为三段式查找 + 三种语法分派。

**支持的解压器**（都必须是命令行版）：

| 工具 | 命令行程序 | 语法 |
|---|---|---|
| NanaZip | `NanaZipC.exe` | 7z |
| 7-Zip | `7z.exe` / `7za.exe` / `7zz.exe` / `7zr.exe` | 7z |
| Bandizip | `bz.exe` | bz |
| WinRAR | `WinRAR.exe` | rar |

**不支持的**：Windows 自带 `tar`/`expand`（读不了 7z）、各类 GUI 版
（`NanaZip.exe`、`7zG.exe`、`Bandizip.exe`、`WinRAR.exe` 的 GUI 模式）。

**查找顺序**：
1. `ZMANUAL` 手动指定（填了就用，不自动找）
2. 脚本同目录
3. 常见安装位置（9 个路径）
4. 系统 PATH

**三种命令行语法的差异**：

```bat
rem 7z 系
"%Z%" x "%P%" -o"%OUT%" %REQ% %EXTRA% -aoa -mmt=%TH%

rem Bandizip（参数顺序不同，无 -mmt）
"%Z%" x -y -o:"%OUT%" "%P%" %REQ% %EXTRA%

rem WinRAR（目标目录在最后且不带 -o，-ibck 后台运行不弹窗）
"%Z%" x -y -ibck "%P%" %REQ% %EXTRA% "%OUT%"
```

用 `goto` 分派而不是 `if/else` 嵌套，每种分支里单独取 `errorlevel`。

**未验证**：WinRAR 和 Bandizip 能否解开 NVIDIA 的 SFX 包。
排在最前的是 NanaZip，实测可用。

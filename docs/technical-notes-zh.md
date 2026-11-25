# 技术说明

这份文档记录 NVLITE 的内部实现细节和踩过的坑，避免后续维护时重犯。

## 设计约定

改代码前先读这四条：

1. **全程不用延迟展开**。所有变量一律 `%VAR%`，脚本开头显式 `setlocal DisableDelayedExpansion`。
   代价是括号块内不能"赋值后立刻读自己刚写的值"，所以脚本刻意不在块内回读。
   好处是彻底避开 `!VAR!` 被路径里的感叹号吃掉的问题。

2. **括号块内绝不出现裸的 echo 路径变量**。路径含右括号会把块截断。
   要么加引号，要么改成 `goto` 结构。

3. **`rem` 注释里不要写尖括号、竖线、和号**。cmd 会把它们当重定向符或命令分隔符。

4. **删除逻辑必须内联，不能提取成 `call :sub`**。
   实测：把删除循环提取成子程序后，删除数量从 312 变成 0，且屏幕上看不出异常。

## 编码

源文件是 **GBK + CRLF**。

- 用 UTF-8 保存会导致中文全部乱码
- 用 LF 换行会导致 `goto` 标签和 `if` 块解析异常
- `.gitattributes` 里固定了 `*.bat text eol=crlf`

## 变量展开的几个坑

### `for` 的 DO 子句只解析一次

```bat
rem 错：多个缺失项会互相覆盖，只报最后一个
set "MISS="
for %%F in (a b c) do if not exist "%%F" set "MISS=%MISS% %%F"

rem 对：一行一个
set "MISS="
if not exist "a" set "MISS=%MISS% a"
if not exist "b" set "MISS=%MISS% b"
if not exist "c" set "MISS=%MISS% c"
```

### `findstr /b` 匹配的是行首

```bat
rem 错：echo 输出以引号开头，永远不匹配，提取逻辑从不执行
echo "!FN!" | findstr /b /c:"-" >nul && for /f "delims=-" %%A in ("!FN!") do set "VER=%%A"

rem 对：直接 for /f，没有连字符时 delims 不分割，取整串
for /f "delims=-" %%A in ("%FN%") do set "VER=%%A"
```

### `for %%F in ()` 是语法错误

配置项清空后必须加守卫：

```bat
if not defined DROP goto :skip
for %%F in (%DROP%) do ...
:skip
```

## 为什么不能删 Display.Driver 内部的文件

**实测证据**：v4.1 把 `DROPDIR` 设成 `NvCamera`，621.40 安装时在"系统"检查阶段
报"所需文件丢失"，安装器直接中止。v4.2 清空 `DROPDIR` 后同一个包安装正常。

**调研结论**：

| 目录 | 作用 | 能否删 |
|---|---|---|
| `NvCamera` | Ansel 游戏内截图 | 不能，实测装不上 |
| `NVCPL` | 控制面板本体 | 不能 |
| `Display.NvContainer` | 控制面板后台服务 | 不能，删了面板打不开 |
| `ngx-builtins` | DLSS 依赖 | 不能，开 DLSS 的游戏会出问题 |
| `NVWMI` | IT 管理用的 WMI 接口 | 能装，但 HWiNFO 这类工具读不到显卡温度 |

参考：NVCleanstall 这类工具走的是**组件级**删除（修改安装配置让安装器不装某个组件），
不是删驱动目录里的文件。它对 Ansel 的处理是**禁用**（`NvCameraConfiguration` 工具），
不是删目录。

**结论**：想省空间只能改 `EXTRA` 那行，别动 `Display.Driver` 里的东西。

## 关于 setup.cfg 过滤

脚本用 `findstr /v` 删掉包含 `EulaHtmlFile` / `FunctionalConsentFile` / `PrivacyPolicyFile`
这三个字符串的所有行。

在 621.x 上实际删掉 79 行（89361 → 77694 字节）：

- 三个变量定义本身
- 三个拼好路径的变量（`EulaHtmlFileFullPath` 等）
- 30 种语言的 `EULAandPrivacyPolicyText`（因为 value 里含 `EulaHtmlFile` 子串）
- 两个 UI 控件定义（`eulaBoxWithNvApp`、`eulaLink`）
- `<manifest>` 段的三个 `<file>` 声明

**为什么必须删**：这些变量指向 `NvApp\Unified_EULA\*.html`，而 `NvApp` 目录不会被提取。
不删的话安装器会去找不存在的文件。

**副作用**：引用它们的界面文字被一并删掉，许可页可能显示不全。
但实测双击 `Setup.exe` 在两个驱动版本上都能正常装完，没有阻碍。

**安全保护**：过滤结果为空时绝不覆盖原文件，否则 `Setup.exe` 直接报错。

## 关于安装参数

`setup.cfg` 的 `<options>` 段定义了官方支持的参数：

```xml
<bool name="enableTelemetry" property="EnableTelemetry"/>
<bool name="clean" property="CleanInstall"/>
<bool name="forcereboot" property="RebootRequired"/>
<bool name="noreboot" property="IgnoreReboot"/>
<bool name="passive" property="ProgressOnly"/>
<bool name="noeula" property="SkipEula"/>
<bool name="nofinish" property="SkipFinish"/>
<bool name="ignorepnp" property="IgnorePnpFlag"/>
<bool name="nosplash" property="NoSplashScreen"/>
```

生成的 `Install_Silent.bat` 用的是：

```bat
Setup.exe -s -noeula -noreboot -nofinish
```

**注意**：这些参数只在**安装流程**层面生效（跳过页面、静默运行），
管不了安装器启动时的文件自检。所以"用静默脚本绕过文件缺失"这个思路是错的。

## 版本演进

| 版本 | 行数 | 状态 |
|---|---|---|
| 原始 NV驱动精简.bat | 67 | 只认 7-Zip，双击闪退，出错无提示 |
| v1.0.2 | 300 | 堆功能，其中"删老系统目录"占 65 行但实测匹配 0 个 |
| v2.0 | 181 | 砍掉空操作和过度设计 |
| v3.1.1 | 178 | **含 2 个静默失效 bug**（`for` 累加覆盖、版本号提取失效） |
| v4.2 | 232 | 4 个 bug 全修，真机验证通过 |
| **v4.3** | **236** | +4 处稳定性加固 |

**教训**：追求行数少（300→165）时把校验压进 `for`，直接埋了 bug。
从那以后不再压行数，每一行都要能说清的作用。

## 真机验证记录

### 621.24 桌面版（2026-11-22）

```
[+] [621.24] 正在解压，请稍候...
[OK] 已生成 Install_Silent.bat
保存路径: C:\Users\<user>\Downloads\621.24-Desktop-Win11
```

安装结果：PhysX 9.26.0904 / HD 音频 1.4.6.6 / 图形驱动 621.24 三项均"已安装"。

### 621.40 桌面版（2026-11-25）

v4.1（删 NvCamera）→ 安装失败"所需文件丢失"
v4.2（清空 DROPDIR）→ 安装正常

## 待验证

- Bandizip `bz.exe` 能否解开 NVIDIA 的 SFX 包（脚本排在最后，失败会提示换 NanaZip）
- 笔记本场景（NVPCF / Optimus 缺失后 Dynamic Boost 的实际影响）
- `Install_Silent.bat` 的静默安装路径（用户一直用 `Setup.exe` 手动装）

@echo off
rem 必须显式关掉：只写 setlocal 会继承外部环境的延迟展开状态，
rem 如果用户系统开了它，路径里的感叹号会被当成变量标记吃掉
setlocal DisableDelayedExpansion
rem ============================================================
rem  NVLITE - 从 NVIDIA 官方驱动包里只提取需要的部分
rem  用法：把驱动包 .exe 拖到这个文件图标上松手
rem  它不装驱动，装驱动靠生成目录里的 Setup.exe 或 Install_Silent.bat
rem
rem  设计约定（改代码前先读）：
rem   1. 全程不用延迟展开，所有变量一律用百分号包裹。代价是括号块内不能
rem      "赋值后立刻读自己刚写的值"，所以本脚本刻意不在块内回读。
rem   2. 括号块内绝不出现裸的 echo 路径变量，避免右括号把块截断。
rem   3. rem 注释里不要写尖括号、竖线、和号。
rem   4. 删除逻辑必须内联，不能提取成 call 子程序（实测会静默失效）。
rem ============================================================
set "TOOLV=4.4.1"
title NVLITE v%TOOLV%

rem --- 1. 取输入 ---
set "P=%~1"
if defined P goto :havep
echo 把 NVIDIA 官方驱动包 .exe 拖到本脚本图标上松开即可。
echo 也可以把 .exe 拖进这个窗口，然后回车。
echo.
set /p "P=驱动包路径: "
rem 下面这行去掉粘贴时可能带上的引号。
rem 加外层引号是为了路径含和号时不被当成命令分隔符。
set "P=%P:"=%"
:havep
if not defined P (echo [错误] 没有提供驱动包 & pause & exit /b 1)
for %%A in ("%P%") do set "P=%%~fA"
if /i not "%P:~-4%"==".exe" (echo [错误] 只接受 .exe 驱动包 & echo        你给的是: "%P%" & pause & exit /b 1)
if not exist "%P%" (echo [错误] 找不到文件: "%P%" & pause & exit /b 1)

rem --- 2. 找解压器 ---
rem NVIDIA 的包是 7z 格式，只认能读 7z 的命令行工具，三种语法：
rem   7z = NanaZip / 7-Zip / 7zr      bz = Bandizip      rar = WinRAR
rem 不含：Windows 自带 tar/expand（读不了 7z）、各 GUI 版（没稳定命令行）
rem 想写死路径就填下面这行，填了就不自动找：
set "ZMANUAL="
rem 例：set "ZMANUAL=C:\Program Files\7-Zip\7z.exe"

rem 候选文件名。同一份清单用于"脚本同目录"和"PATH 里找"
set "ZCAND=NanaZipC.exe 7z.exe 7za.exe 7zz.exe 7zr.exe bz.exe WinRAR.exe"
set "Z=%ZMANUAL%"

rem 1) 脚本同目录（绿色版 / 便携版放这里最省事）
if not defined Z for %%N in (%ZCAND%) do if not defined Z if exist "%~dp0%%N" set "Z=%~dp0%%N"

rem 2) 常见安装位置
if not defined Z for %%X in (
    "C:\Program Files\NanaZip\NanaZipC.exe"
    "%LOCALAPPDATA%\Microsoft\WindowsApps\NanaZipC.exe"
    "C:\Program Files\7-Zip\7z.exe"
    "C:\Program Files (x86)\7-Zip\7z.exe"
    "%LOCALAPPDATA%\Programs\7-Zip\7z.exe"
    "C:\Program Files\Bandizip\bz.exe"
    "%LOCALAPPDATA%\Programs\Bandizip\bz.exe"
    "C:\Program Files\WinRAR\WinRAR.exe"
    "C:\Program Files (x86)\WinRAR\WinRAR.exe"
) do if not defined Z if exist %%X set "Z=%%~X"

rem 3) PATH 里找
if not defined Z for %%N in (%ZCAND%) do if not defined Z for /f "delims=" %%A in ('where %%N 2^>nul') do if not defined Z set "Z=%%A"

if not defined Z goto :nozip

rem 4) 按文件名判定用哪套参数
set "ZM=7z"
if /i "%Z:~-7%"=="\bz.exe" set "ZM=bz"
if /i "%Z:~-11%"=="\WinRAR.exe" set "ZM=rar"
goto :filever

:nozip
echo [错误] 没找到可用的解压器。
echo.
echo        NVIDIA 驱动包是 7z 格式，需要下面任意一个命令行工具：
echo          NanaZip     NanaZipC.exe
echo          7-Zip       7z.exe / 7za.exe / 7zz.exe / 7zr.exe
echo          Bandizip    bz.exe
echo          WinRAR      WinRAR.exe
echo.
echo        三种解决办法，任选：
echo          1. 装上面任意一个（NanaZip 或 7-Zip 最省事）
echo          2. 把 NanaZipC.exe 或 7z.exe 放到本脚本同目录
echo          3. 在本脚本里给 ZMANUAL 填上完整路径
echo.
echo        注意：Windows 自带的压缩功能读不了这种包，必须装上面这些。
pause & exit /b 1

:filever
rem --- 3. 线程数与输出目录名 ---
set "TH=%NUMBER_OF_PROCESSORS%"
if not defined TH set "TH=4"
if %TH% LSS 1 set "TH=4"
if %TH% GTR 8 set "TH=8"
for %%A in ("%P%") do set "FN=%%~nA"
for %%A in ("%P%") do set "OUTP=%%~dpA"
set "VER=%FN%"
for /f "delims=-" %%A in ("%FN%") do set "VER=%%A"
set "SUF=-Desktop-Win11"
echo "%FN%" | find /i "Notebook" >nul && set "SUF=-Laptops-Win11"
set "OUT=%OUTP%%VER%%SUF%"

rem --- 4. 提取与删除清单（改这里就能调精简程度）---
rem 必需：驱动本体 / 安装器 / setup 入口与配置 / 设备列表
set "REQ=Display.Driver NVI2 setup.exe setup.cfg ListDevices.txt"
rem 额外组件，不需要就把词删掉：
rem   PhysX    物理引擎，只有少数老游戏用
rem   HDAudio  HDMI/DP 音频，只有用显示器喇叭出声才需要
rem   EULA.txt 许可文本，新版驱动可能没有，有就带上
set "EXTRA=PhysX HDAudio EULA.txt"
rem 提取后要删掉的文件（按文件名在整个 Display.Driver 树里递归找，找不到就跳过）
rem 621.40 实测：包里已经没有 nvdrsdb0.bin / nvdrsdb1.bin，所以默认留空。
rem 老驱动（5xx 之前）如果要删控制面板的 3D 预设库，填：
rem     set "DROP=nvdrsdb0.bin nvdrsdb1.bin"
rem 注意：绝对不要填 nvxdapix.dll，那是控制面板组件，
rem       删了 NVDisplay.Container 会崩溃、面板打不开。
set "DROP="
rem 提取后要删掉的子目录（在 Display.Driver 里）。默认留空，一个都不删。
rem
rem 【重要】NvCamera 实测会导致安装失败：
rem   621.40 上用 set "DROPDIR=NvCamera" 删掉后，安装器报"所需文件丢失"，
rem   在"系统"检查这一步就中止。所以默认不删。
rem
rem 以下目录都不能删，删了会出问题：
rem   NvCamera            Ansel 截图，删了装不上（实测）
rem   NVCPL               控制面板本体
rem   Display.NvContainer 控制面板后台服务，删了面板打不开
rem   ngx-builtins        DLSS 依赖，开 DLSS 的游戏会出问题
rem   NVWMI               WMI 监控接口，HWiNFO 这类工具会读不到显卡信息
set "DROPDIR="

rem --- 5. 建输出目录。同名目录只删本工具自己生成的 ---
if not exist "%OUT%" goto :mkout
rem 上次 rd 可能删掉了标记文件但目录没删干净，所以再加一个备用判据
if not exist "%OUT%\nvlite_log.txt" if not exist "%OUT%\Display.Driver\" goto :notmine
echo [提示] 上次生成的同版本目录已存在，将重建
rd /q /s "%OUT%" >nul 2>&1
if exist "%OUT%" (echo [错误] 旧目录删不掉，可能被资源管理器或杀软占用 & pause & exit /b 1)
goto :mkout

:notmine
echo [错误] 同名目录已存在，但不是本工具生成的：
echo        "%OUT%"
echo        为防误删你的文件，已停止。请手动改名或删除后重试。
pause & exit /b 1

:mkout
mkdir "%OUT%" >nul 2>&1
if exist "%OUT%" goto :mkdone
echo [错误] 创建目录失败，可能被杀软阻止:
echo        "%OUT%"
pause & exit /b 1

:mkdone
set "LOG=%OUT%\nvlite_log.txt"
set "DDF=%OUT%\Display.Driver"
>"%LOG%" echo [NVLITE v%TOOLV%] %date% %time%
>>"%LOG%" echo [ZIP] %Z% (模式 %ZM%)
>>"%LOG%" echo [REQ] %REQ% %EXTRA%
>>"%LOG%" echo [DROP] %DROP% / %DROPDIR%

echo [+] 正在解压 %VER%，请稍候（约 1-2 分钟）...

rem --- 6. 核心：只提取白名单，其余不解压 ---
rem 三种命令行语法不同，用 goto 分派。每种分支里单独取 errorlevel，
rem 避免 goto 干扰取值时机。
if "%ZM%"=="bz" goto :x_bz
if "%ZM%"=="rar" goto :x_rar
rem 默认：7z 系（NanaZip / 7-Zip / 7zr）
"%Z%" x "%P%" -o"%OUT%" %REQ% %EXTRA% -aoa -mmt=%TH% >>"%LOG%" 2>&1
set "RC=%errorlevel%"
goto :x_done

:x_bz
rem Bandizip：参数顺序不同，-y 自动覆盖，没有 -mmt
"%Z%" x -y -o:"%OUT%" "%P%" %REQ% %EXTRA% >>"%LOG%" 2>&1
set "RC=%errorlevel%"
goto :x_done

:x_rar
rem WinRAR：目标目录放在最后且不带 -o，-ibck 让它后台运行不弹窗
"%Z%" x -y -ibck "%P%" %REQ% %EXTRA% "%OUT%" >>"%LOG%" 2>&1
set "RC=%errorlevel%"

:x_done

rem --- 7. 校验必需项（缺任何一项都不该继续）---
rem 这里必须一行一个，不能塞进 for：for 的 DO 子句只解析一次，
rem 循环里写 %MISS% 会拿到旧值，多个缺失项会互相覆盖
set "MISS="
if not exist "%OUT%\setup.exe" set "MISS=%MISS% setup.exe"
if not exist "%OUT%\setup.cfg" set "MISS=%MISS% setup.cfg"
if not exist "%OUT%\Display.Driver\" set "MISS=%MISS% Display.Driver\"
if not exist "%OUT%\NVI2\" set "MISS=%MISS% NVI2\"
if not defined MISS goto :chkdone
echo [错误] 解压不完整，缺少:%MISS%
echo        解压器退出码 %RC%，详见日志:
echo        "%LOG%"
pause & exit /b 1

:chkdone
rem 安装器核心 DLL：只记进日志，不影响流程
rem （各版本存放层级不同，硬拦会让整个包用不了）
set "DLLMISS="
if not exist "%OUT%\NVI2\NVI2.dll" set "DLLMISS=%DLLMISS% NVI2.dll"
if not exist "%OUT%\NVI2\NvInstallerUtil.dll" set "DLLMISS=%DLLMISS% NvInstallerUtil.dll"
if not exist "%OUT%\NVI2\NVI2UI.dll" set "DLLMISS=%DLLMISS% NVI2UI.dll"
if not exist "%OUT%\NVI2\NVPrxy32.dll" set "DLLMISS=%DLLMISS% NVPrxy32.dll"
if not exist "%OUT%\NVI2\NVPrxy64.dll" set "DLLMISS=%DLLMISS% NVPrxy64.dll"
if defined DLLMISS >>"%LOG%" echo [INFO] NVI2 根目录缺少:%DLLMISS%（可能在子目录，一般不影响）

rem --- 8. 删掉清单里的文件和子目录 ---
set "TRIM=0"
if not exist "%DDF%" goto :trimdir
rem 清单为空时不能进 for，cmd 里 for %%F in () 是语法错误
if not defined DROP goto :trimdir
for %%F in (%DROP%) do for /f "delims=" %%X in ('dir /s /b "%DDF%\%%F" 2^>nul') do (
    >>"%LOG%" echo [TRIM] "%%X"
    del /q "%%X" >nul 2>&1
    if not exist "%%X" set /a TRIM+=1 >nul
)

:trimdir
rem 同样，清空 DROPDIR 后要跳过这个循环
if not defined DROPDIR goto :trimdone
for %%D in (%DROPDIR%) do if exist "%DDF%\%%D\" (
    >>"%LOG%" echo [TRIMDIR] "%%D"
    rd /q /s "%DDF%\%%D" >nul 2>&1
    if not exist "%DDF%\%%D\" set /a TRIM+=1 >nul
)

:trimdone
if %TRIM% GTR 0 echo [精简] 额外移除 %TRIM% 项（明细见日志）
>>"%LOG%" echo [LIST] Display.Driver 下的子目录:
for /d %%D in ("%DDF%\*") do >>"%LOG%" echo    %%~nxD

rem --- 9. 去掉安装向导的同意页 ---
rem 这三个键指向 NvApp 目录里的协议网页，而 NvApp 不提取，
rem 不删这些行安装器会去找不存在的文件。
rem 副作用：引用它们的界面文字也会被删掉，许可页可能显示不全。
set "CFG=%OUT%\setup.cfg"
if not exist "%CFG%" goto :cfgdone
copy /y "%CFG%" "%CFG%.bak" >nul 2>&1
findstr /v "EulaHtmlFile FunctionalConsentFile PrivacyPolicyFile" "%CFG%" > "%CFG%.tmp" 2>>"%LOG%"
set "TMPZ=0"
for %%A in ("%CFG%.tmp") do set "TMPZ=%%~zA"
if not defined TMPZ set "TMPZ=0"
if %TMPZ% GTR 0 goto :cfgmoved
rem 过滤结果为空时绝不能覆盖原文件，否则 Setup.exe 直接报错
del /q "%CFG%.tmp" >nul 2>&1
echo [提示] setup.cfg 无需过滤，已保留原文件
goto :cfgdone

:cfgmoved
move /y "%CFG%.tmp" "%CFG%" >nul 2>&1
rem 覆盖失败时（杀软或占用）必须提示，否则许可页过滤会静默失效
if exist "%CFG%.tmp" echo [警告] setup.cfg 覆盖失败，许可页过滤未生效，装驱动时会显示协议页

:cfgdone
rem --- 10. 生成静默安装脚本 ---
set "SB=%OUT%\Install_Silent.bat"
>"%SB%" echo @echo off
>>"%SB%" echo cd /d "%%~dp0"
>>"%SB%" echo Setup.exe -s -noeula -noreboot -nofinish
>>"%SB%" echo echo.
>>"%SB%" echo echo 安装结束，退出码 %%errorlevel%%
>>"%SB%" echo pause ^>nul
if exist "%SB%" (echo [OK] 已生成 Install_Silent.bat) else (echo [提示] 静默脚本没生成成功，用 Setup.exe 手动装)

rem --- 11. 完成 ---
echo.
echo ======================================================
echo   处理完成        NVLITE v%TOOLV%
echo   --------------------------------------------------
echo   保存路径: "%OUT%"
echo   装驱动  : 右键 Install_Silent.bat 以管理员运行
echo   日志    : nvlite_log.txt
echo ======================================================
echo.
echo 按任意键退出...
pause >nul
exit /b 0

# 交接文档

写给接手这个项目的下一个会话。读这一份就够了，细节在 `docs/technical-notes-zh.md`。

最后更新：2026-11-25

---

## 一、现在是什么状态

| 项 | 值 |
|---|---|
| 版本 | v4.4.1，285 行（CRLF） |
| 仓库 | https://github.com/bdd669/nvlite （public） |
| 最新 release | v4.4（v4.4.1 只有引号修正，未单独发 release） |
| 真机验证 | 621.24 桌面版装上、621.40 桌面版装上 |
| 当前可用 | 是，没有已知会导致失败的问题 |

## 一之二、真机测试环境

| 项 | 值 |
|---|---|
| 系统 | Windows 11 x64，管理员账户 |
| 解压器 | NanaZip（Microsoft Store 版），`NanaZipC.exe` |
| 驱动包 | `621.24-desktop-win10-win11-64bit-international-nsd-dch-whql.exe`（991 MiB）|
| | `621.40-desktop-win10-win11-64bit-international-nsd-dch-whql.exe`（988 MiB）|
| 显卡型号 | **未记录**，接手时建议补上 |
| 安装方式 | 双击 `Setup.exe` 手动装（`Install_Silent.bat` 从未实测） |

输出目录里有一份 `nvlite_log.txt`，是 621.24 那次的完整日志，脱敏样例见
[`docs/log-sample.txt`](docs/log-sample.txt)。判断一次新失败是回归还是环境问题，
先拿它对比。

## 二、目录结构

所有东西都在 `/home/bdd669/nvlite`，一个目录，既是工作区也是 git 仓库。

会提交的：

| 文件 | 说明 |
|---|---|
| `NVLITE.bat` | 主程序，文件名不带版本号 |
| `README.md` / `README.en.md` | 中英文说明，中文是默认显示 |
| `DISCLAIMER.md` | AI 开发声明，含测试范围和风险 |
| `LICENSE` | MIT，头部有一行 AI 注明 |
| `AGENTS.md` | 给 AI 会话的约定，四条铁律在那里 |
| `HANDOFF.md` | 就是这份 |
| `docs/technical-notes-zh.md` | 技术细节、踩过的坑、版本演进 |

不提交的（`.gitignore` 排除）：

| 路径 | 原因 |
|---|---|
| `归档/` | 历史版本。**注意 `NVLITE.bat.call-坏了`、`NVLITE_v3.1.1.bat.bak`、`NVLITE_v4.1.bat.bak` 这三个有已知 bug，只供对照，不要当参考实现** |
| `实测样本/` | 真机测试产物，含本机用户路径 |
| `项目说明.md` | 内部记录，内容已并入 docs |
| `NVLITE_使用说明.txt` | 和 README 重复 |

**发版流程**：改 `NVLITE.bat` → 真机验证 → 把 `cp NVLITE.bat 归档/NVLITE_vX.Y.bat` →
同步文档 → commit → `gh release create` 附 bat 和 zip。

## 三、脚本干什么

用户把 NVIDIA 官方驱动包 `.exe` 拖到脚本上，脚本用命令行解压器
（NanaZipC / 7z / bz / WinRAR）只解压白名单条目到输出目录，然后过滤 `setup.cfg`、
生成静默安装脚本。用户去输出目录里装驱动。

核心就一条 `7z x` 命令，其余全是保护逻辑。

## 四、必须遵守的设计约束

看 [`AGENTS.md`](AGENTS.md)，那四条铁律 + `for` 的坑。这里不重复。

## 五、白名单和可配置项

脚本顶部：

```bat
set "ZMANUAL="                                          解压器路径（填了就不自动找）
set "ZCAND=NanaZipC.exe 7z.exe 7za.exe 7zz.exe 7zr.exe bz.exe WinRAR.exe"
set "REQ=Display.Driver NVI2 setup.exe setup.cfg ListDevices.txt"   必需
set "EXTRA=PhysX HDAudio EULA.txt"                      可加可减
set "DROP="                                             保持空
set "DROPDIR="                                          保持空
```

`EXTRA` 是唯一安全有效的精简开关：

| 去掉 | 省 | 代价 |
|---|---|---|
| `PhysX` | ~50 MB | 少数老游戏没 GPU 物理 |
| `HDAudio` | ~20 MB | 显示器/电视喇叭不出声 |

## 六、为什么 `DROP` / `DROPDIR` 必须保持空

实测过：`DROPDIR=NvCamera` 时，621.40 安装报"所需文件丢失"，在"系统"检查就中止。
清空后同一个包装正常。

`Display.Driver` 里有 5 个子目录，一个都不能删：

| 目录 | 作用 |
|---|---|
| `NvCamera` | Ansel 截图。**删了装不上** |
| `NVCPL` | 控制面板本体 |
| `Display.NvContainer` | 控制面板后台服务 |
| `ngx-builtins` | DLSS 依赖 |
| `NVWMI` | IT 管理的 WMI 接口。能装，但 HWiNFO 读不到显卡温度 |

想精简只能改 `EXTRA`，不能删驱动内部文件。

## 七、一个重要的产品背景

**610 系驱动之后，NVIDIA 不再把经典控制面板打包进驱动**，它变成了
`Display.NvApp.NvCPL`（NVIDIA App 的子组件）。

所以在新驱动上用这个脚本，**装完没有控制面板**。两个办法：

1. 装完去 Microsoft Store 装 "NVIDIA Control Panel"（独立 Appx）—— **未验证**
2. 用官方完整包

这一条已写进 README 和 DISCLAIMER，**不要删**，否则会有人来问。

## 八、已知限制

| 限制 | 原因 |
|---|---|
| 路径不能含圆括号 | `for /f in ('dir ...')` 里括号会提前结束循环头 |
| 只接受 `.exe` | 不接受 `.zip` |
| 笔记本不推荐 | `NVPCF` 没提取，Dynamic Boost 可能失效 |
| Bandizip / WinRAR 未验证 | 代码写了，参数语法查过资料，没实测 |

## 九、下一步可以做什么

按价值排序：

1. **验证 Store 版控制面板能否配精简驱动** —— 这决定项目还有没有实用价值。
   在装了 v4.4 输出的机器上，去 Microsoft Store 搜 "NVIDIA Control Panel" 装一下，
   看能不能打开、能不能读显卡设置。
2. **验证 7-Zip 分支** —— 在一台只装了 7-Zip 的机器上跑一次。
3. **验证 Bandizip / WinRAR 分支** —— 同上，最好用一台备用机。
4. 笔记本场景实测（NVPCF 缺失的实际影响）—— 需要一台笔记本，风险较高。
5. 如果上面都验证了，考虑加一个"批量处理多个驱动包"的功能。

**不要做的**：

- 不要在 `Display.Driver` 里找东西删（已确认路走不通）
- 不要为了行数精简校验代码
- 不要凭名字猜组件用途

## 十、历史决策记录

| 版本 | 行数 | 发生了什么 |
|---|---|---|
| 原始脚本 | 67 | 只认 7-Zip，双击闪退，出错无提示 |
| v1.0.2 | 300 | 堆功能。其中"删老系统目录"占 65 行，实测匹配 0 个 |
| v2.0 | 181 | 砍掉空操作 |
| v3.1.1 | 178 | **含 2 个静默失效 bug**：`for` 累加覆盖、`findstr /b` 版本号提取失效 |
| v4.2 | 232 | 4 个 bug 全修，真机验证通过 |
| v4.3 | 236 | 4 处稳定性加固（`DisableDelayedExpansion`、备用判据等） |
| v4.4 | 285 | 解压器支持扩展到 4 种工具、3 种语法 |
| **v4.4.1** | **285** | 块内裸 echo 变量补引号（死代码路径），文档修正 |

行数从 165 涨到 285 是故意的。165 是 v2.0 之后某一版的中间状态（不在上表里），
当时为了"精简"把校验压进 `for`，直接埋了 bug。从那以后不再压行数。

## 十一、AI 开发的背景

所有代码由 AI 生成，人类提供需求、判断和真机测试。详见
[`DISCLAIMER.md`](DISCLAIMER.md)。

AI 在这个项目里犯过的错（都已修，写在这里提醒下一个会话）：

1. 删除循环提取成子程序 → 静默失效，删了 0 个文件，屏幕无异常
2. `findstr /b` 检查行首 → `echo "内容"` 以引号开头，永远不匹配，版本号提取从未执行
3. `for` 里 `set "MISS=%MISS% x"` → 每次覆盖，多个缺失项只报最后一个
4. 建议删 `nvxdapix.dll`（以为"DX 兼容层用不到"）→ 实际删了控制面板会崩
5. 采纳 `chcp 65001` 建议 → GBK 字节配 UTF-8 代码页，中文全乱码

**教训：改完必须真机验证。生成成功不代表能装上。**

## 十二、常见问题

**Q: 改了脚本怎么验证？**
A: 拖入驱动包生成，然后进输出目录实际装一遍。只看生成成功不够。

**Q: git push 报 TLS 错误？**
A: 这台机器的 GnuTLS 问题，已配 `http.version=HTTP/1.1` 和 `http.postBuffer`。重试。

**Q: 用户说装不上怎么办？**
A: 让他提供输出目录里的 `nvlite_log.txt`，和具体现象。先让他清空 `DROP` / `DROPDIR`
重试，排除这两个变量的影响。

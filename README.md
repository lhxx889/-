# 小白用户超级简易使用指南
我理解您需要一个可以直接从GitHub远程下载并自动解压安装的命令。以下是一个简单的一行命令，可以直接从GitHub下载、解压并运行安装脚本：curl -sSL https://raw.githubusercontent.com/lhxx889/-/refs/heads/main/super_easy_install.sh | bash
## 一、安装步骤（只需一次）

### 方法一：复制粘贴一行命令（最简单）

1. 打开终端（按 Ctrl+Alt+T）
2. 复制粘贴以下命令，然后按回车：

```
wget -O install.sh https://raw.githubusercontent.com/用户名/crypto_monitor/main/super_easy_install.sh && chmod +x install.sh && ./install.sh
```

### 方法二：下载后手动运行

1. 下载 `super_easy_install.sh` 文件到您的电脑
2. 右键点击文件，选择"属性"，在"权限"选项卡中勾选"允许作为程序执行"
3. 双击文件运行，或在终端中输入 `./super_easy_install.sh`

## 二、首次运行设置

首次运行时，您需要设置Telegram机器人：

1. 在Telegram中搜索 `@BotFather`
2. 发送 `/newbot` 命令创建新机器人
3. 按照提示设置机器人名称和用户名
4. 获取机器人Token（看起来像：`123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ`）
5. 创建一个Telegram群组或频道，将机器人添加为管理员
6. 获取群组ID或频道用户名（如：`-1001234567890`或`@your_channel`）

当程序提示时，输入上面获取的Token和群组ID/频道用户名。

## 三、日常使用（安装后）

安装完成后，您可以通过以下任一方式启动监控系统：

1. 双击桌面上的 `Crypto Monitor` 图标
2. 双击主目录中的 `启动加密货币监控.sh` 文件
3. 在终端中运行: `~/crypto_monitor/start_monitor.sh`

## 四、使用交互式菜单

程序启动后会显示交互式菜单，您可以：

1. 查看所有可用API地址
2. 切换到主API地址或备用API地址
3. 添加自定义API地址
4. 测试当前API地址连接
5. 暂停/恢复监控
6. 退出菜单或程序

只需输入对应的数字并按回车即可。

## 五、常见问题

### 1. 如何获取Telegram Bot Token？

1. 在Telegram中搜索 `@BotFather`
2. 发送 `/newbot` 命令
3. 按照提示完成创建
4. 复制BotFather发给您的Token

### 2. 如何获取Telegram群组ID？

1. 创建一个新群组
2. 将 `@RawDataBot` 机器人添加到群组
3. 群组ID会显示在机器人发送的消息中（格式如：`-1001234567890`）

### 3. 程序无法连接API怎么办？

使用交互式菜单中的"切换到备用API地址"或"测试当前API地址连接"功能。

### 4. 如何更新程序？

重新运行安装脚本即可，它会自动备份旧版本并安装新版本。

### 5. 如何完全卸载？

删除 `~/crypto_monitor` 目录和桌面上的快捷方式即可。

## 六、联系与支持

如有任何问题或需要帮助，请通过以下方式联系我们：

- GitHub Issues: https://github.com/用户名/crypto_monitor/issues
- 电子邮件: 

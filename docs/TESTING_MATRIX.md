# Gal4Mac 测试游戏清单

## 优先级 1：必须测（引擎覆盖广）

### KiriKiri/KAG 引擎（覆盖60% galgame市场）

| 游戏 | 推荐度 | 备注 |
|------|--------|------|
| **CLANNAD HD** | ⭐⭐⭐⭐⭐ | Key社经典，Steam有售 |
| **ONE ~光辉的季节~** | ⭐⭐⭐⭐⭐ | Steam有售 |
| **寒蝉鸣泣之时 奉** | ⭐⭐⭐⭐ | Steam有售，08th expansion |
| **魔女的夜宴** | ⭐⭐⭐⭐ | SAGA PLANTS，Steam有售 |
| **MOON.** | ⭐⭐⭐ | 免费同人，验证基础 |

### Unity VN

| 游戏 | 推荐度 | 备注 |
|------|--------|------|
| **Aokana** | ✅ 已完成 | NekoNyanSoft版 |

### TyranoScript

| 游戏 | 推荐度 | 备注 |
|------|--------|------|
| **The Letter** | ⭐⭐⭐⭐ | 恐怖galgame，itch.io 免费 |
| **SC2VN** | ⭐⭐⭐ | 同人星际2，免费 |
| **永别了 我的爱** | ⭐⭐⭐ | itch.io 免费 |

### Ren'Py（验证原生兼容）

| 游戏 | 推荐度 | 备注 |
|------|--------|------|
| **Doki Doki Literature Club** | ⭐⭐⭐⭐⭐ | Steam免费，超经典 |
| **Everlasting Summer** | ⭐⭐⭐ | 免费同人 |
| **ourCGA** 等 RPG | ⭐⭐ | 通用 |

### RealLive / NScripter（老引擎挑战）

| 游戏 | 推荐度 | 备注 |
|------|--------|------|
| **月姬 (Tsukihime)** | ⭐⭐⭐⭐⭐ | TYPE-MOON经典（重制版也可） |
| **To Heart** | ⭐⭐⭐ | Leaf社 |
| **BALDR SKY** | ⭐⭐⭐ | 戯画（可能也有问题） |

## 优先级 2：可选测

### 复杂场景
- 视频播放（WMV/MPEG）
- 32位 vs 64位
- 高分辨率（1920x1080+）
- 全屏 vs 窗口
- 日文 vs 中文 vs 英文

## 下载建议

- **Steam**：最方便，正版
- **itch.io**：大量免费/低价同人
- **DLsite**：日文galgame源头
- **视觉小说数据库 (vndb.org)**：查询引擎类型

## 测试流程

1. 下载游戏到 `~/Downloads/<game_name>/`
2. 移动到 `/Users/chenmou2012/gal4mac/<game_name>/`
3. 识别引擎（看文件结构）
4. 创建 `<game_name>.sh` 启动脚本
5. 运行游戏，记录日志
6. 更新 `MVP_REPORT.md`

## 兼容性检查清单

- [ ] 启动成功
- [ ] 主菜单显示
- [ ] 文字正常
- [ ] 字体（中日英）正常
- [ ] 立绘显示
- [ ] 背景显示
- [ ] BGM 播放
- [ ] 语音播放
- [ ] 视频播放（如果有）
- [ ] 存档功能
- [ ] 全屏切换
- [ ] 退出正常

下载好后告诉我，我会自动识别引擎并配置。

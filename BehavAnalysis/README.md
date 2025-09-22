# BehaviorAnalysis System

## 概述

BehaviorAnalysis是一个现代化的行为数据分析系统，完全实现了DataAnalysis模块的所有功能，并提供了更强大的扩展性和可维护性。

## 功能特性

### 核心功能（与DataAnalysis兼容）
- ✅ **数据加载**: GUI数据选择，支持Bpod数据格式
- ✅ **时间戳提取**: 提取舔舐事件时间戳
- ✅ **数据预处理**: 刺激对齐，首次舔舐时间计算
- ✅ **命中率分析**: 按强度计算命中率，心理测量曲线拟合
- ✅ **延迟分析**: 反应时间统计，箱线图分析
- ✅ **可视化**: 直方图、栅格图、命中率曲线、延迟图

### 新增功能
- 🚀 **实时分析**: 实验过程中的实时数据分析
- 🚀 **批量处理**: 多文件批量分析
- 🚀 **配置驱动**: JSON配置文件，易于定制
- 🚀 **模块化设计**: 面向对象架构，易于扩展
- 🚀 **统计测试**: Kruskal-Wallis检验，多重比较
- 🚀 **错误处理**: 完善的错误处理和验证

## 快速开始

### 1. 基本使用

```matlab
% 运行完整分析（等价于DataAnalysis/MainAnalysis.m）
main_analysis('complete')

% 分析特定数据文件
main_analysis('complete', 'path/to/data.mat')

% 运行后分析
main_analysis('post_hoc', 'path/to/data.mat')

% 批量分析
main_analysis('batch', 'path/to/data/directory')
```

### 2. 便捷函数

```matlab
% 使用便捷函数
runCompleteAnalysis()  % 等价于 main_analysis('complete')
runCompleteAnalysis('path/to/data.mat')
```

### 3. 高级API使用

```matlab
% 初始化分析管理器
configPath = 'BehavAnalysis/config.json';
analysisManager = BehaviorAnalysisManager(configPath);

% 加载数据
[SessionData, Session_tbl, filePath] = analysisManager.DataLoader.loadSessionData();

% 处理数据
data = struct('SessionData', SessionData, 'Session_tbl', Session_tbl, 'filePath', filePath);
processedData = analysisManager.Preprocessor.processSessionData(data);

% 运行分析
hitRateResults = analysisManager.Analyzers.postHoc.hit_rate.analyze(processedData);
latencyResults = analysisManager.Analyzers.postHoc.latency.analyze(processedData);

% 创建可视化
analysisManager.Visualizers.raster.createRasterPlot(processedData);
analysisManager.Visualizers.hitRate.createHitRatePlot(hitRateResults.hitRateTable);
```

## 系统架构

### 核心组件

1. **BehaviorAnalysisManager**: 主管理器，协调所有组件
2. **DataLoader**: 数据加载器，支持GUI和程序化加载
3. **DataPreprocessor**: 数据预处理器，时间对齐和特征提取
4. **Analyzers**: 分析器集合
   - `HitRateAnalyzer`: 命中率分析
   - `LatencyAnalyzer`: 延迟分析
5. **Visualizers**: 可视化器集合
   - `RasterVisualizer`: 栅格图和直方图
   - `HitRateVisualizer`: 命中率和延迟图
6. **AnalysisConfig**: 配置管理器

### 设计模式

- **管理器模式**: 统一管理所有组件
- **工厂模式**: 动态创建分析器
- **策略模式**: 不同分析器实现不同策略
- **配置模式**: 外部化配置参数

## 配置文件

系统使用`config.json`进行配置：

```json
{
    "data_settings": {
        "sampling_rate": 1000,
        "file_format": "mat",
        "default_data_path": "G:\\Data\\OperantConditioning\\Yudi"
    },
    "analysis_settings": {
        "post_hoc": {
            "enabled": true,
            "analysis_types": ["hit_rate", "latency", "psychometric", "chronometric"]
        }
    },
    "visualization_settings": {
        "raster_plot": {
            "enabled": true,
            "color_map": "turbo",
            "marker_size": 8
        }
    }
}
```

## 与DataAnalysis的对比

| 特性 | DataAnalysis | BehaviorAnalysis |
|------|-------------|------------------|
| **编程范式** | 过程式 | 面向对象 |
| **代码组织** | 单一脚本 | 模块化设计 |
| **可扩展性** | 低 | 高 |
| **配置管理** | 硬编码 | 外部配置 |
| **实时分析** | 不支持 | 支持 |
| **批量处理** | 不支持 | 支持 |
| **错误处理** | 基础 | 完善 |
| **测试性** | 困难 | 容易 |

## 测试

运行测试脚本验证系统功能：

```matlab
% 运行基本测试
test_behavior_analysis()

% 查看使用示例
example_usage()
```

## 文件结构

```
BehavAnalysis/
├── main_analysis.m              # 主分析脚本
├── BehaviorAnalysisManager.m    # 主管理器
├── DataLoader.m                 # 数据加载器
├── DataPreprocessor.m           # 数据预处理器
├── BaseAnalyzer.m               # 分析器基类
├── HitRateAnalyzer.m            # 命中率分析器
├── LatencyAnalyzer.m            # 延迟分析器
├── AnalyzerFactory.m            # 分析器工厂
├── RasterVisualizer.m           # 栅格图可视化器
├── HitRateVisualizer.m          # 命中率可视化器
├── AnalysisConfig.m             # 配置管理器
├── config.json                  # 配置文件
├── example_usage.m              # 使用示例
├── test_behavior_analysis.m     # 测试脚本
└── README.md                    # 说明文档
```

## 扩展开发

### 添加新的分析器

1. 继承`BaseAnalyzer`类
2. 实现`analyze`方法
3. 在`AnalyzerFactory`中注册

```matlab
classdef MyAnalyzer < BaseAnalyzer
    properties
        AnalyzerName = 'my_analyzer'
        RequiredParameters = {'param1', 'param2'}
    end
    
    methods
        function results = analyze(obj, data)
            % 实现分析逻辑
            results = struct();
        end
    end
end
```

### 添加新的可视化器

1. 创建新的可视化器类
2. 实现可视化方法
3. 在`BehaviorAnalysisManager`中注册

## 故障排除

### 常见问题

1. **数据加载失败**: 检查数据路径和文件格式
2. **分析器错误**: 检查输入数据是否包含必需字段
3. **可视化问题**: 检查MATLAB图形设置

### 调试模式

启用详细输出：

```matlab
% 在配置中设置调试模式
config.DebugMode = true;
```

## 贡献

欢迎贡献代码和改进建议。请遵循以下原则：

1. 保持代码风格一致
2. 添加适当的注释
3. 编写测试用例
4. 更新文档

## 许可证

与主项目保持一致的许可证。

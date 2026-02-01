# Deus - Godot ECS Pipeline Architecture

> Godot 4.x lacks native ECS and pipeline orchestration - Deus adds component-based entities, auto-discovered pipeline stages, and runtime pipeline injection as a GDScript plugin.

## Quick Start

1. Copy `addons/deus/` into your Godot project's `addons/` directory
2. Enable the plugin: **Project > Project Settings > Plugins > Deus**
3. The `Deus` singleton is now available globally

```gdscript
# health.gd - Define a component (pure data, extends Resource)
class_name Health extends DefaultComponent
@export var value: int = 0
```

```gdscript
# heal_pipeline.gd - Define a pipeline (logic via static _stage_ methods)
class_name HealPipeline extends DefaultPipeline
static func _requires(): return [Health]
static func _stage_heal(context):
    context.Health.value += 20
```

```gdscript
# Use it from any script
func _ready():
    var health = Health.new()
    health.value = 100
    Deus.set_component(self, Health, health)
    Deus.execute_pipeline(HealPipeline, self)
```

## About

Godot's node/scene tree works well for most games, but falls short when you need data-oriented composition, structured logic pipelines, or runtime behavior injection. Deus is a GDScript plugin that adds three things to Godot 4.x:

1. An **ECS layer** where any Node becomes an entity by attaching Resource-based components. Entity IDs are assigned lazily via node metadata, and components are stored in SparseSet arrays for O(1) add, remove, and lookup.
2. A **pipeline architecture** where logic is written as static `_stage_` methods on pipeline classes. Stages are auto-discovered via reflection and executed in declaration order against entities matching component and node filters. All component writes are buffered on the `PipelineContext` and committed atomically after stages complete - if any stage fails or cancels, no writes are applied.
3. **Pipeline injection** that lets you insert logic before or after any pipeline stage at runtime, attach result handlers triggered by pipeline outcome, and mark pipelines as one-shot for auto-deregistration.

The `Deus` autoload singleton is the single entry point for all operations. User code always goes through `Deus.*` methods; internal registries and managers are not accessed directly.

## Examples

### Components and pipelines

Components extend `DefaultComponent` (which extends `Resource`) and contain only `@export` data fields. Pipelines extend `DefaultPipeline` and declare required components via `_requires()`. Stages run in declaration order.

```gdscript
# health.gd
class_name Health extends DefaultComponent
@export var value: int = 0
```

```gdscript
# damage.gd
class_name Damage extends DefaultComponent
@export var value: int = 0
```

```gdscript
# damage_pipeline.gd
class_name DamagePipeline extends DefaultPipeline
static func _requires(): return [Health, Damage]
static func _require_nodes(): return [[StaticBody2D], ["Area"]]

static func _stage_deduct(context):
    context.Health.value -= context.Damage.value
    context.Damage.value = 0
```

Component filters control which entities a pipeline operates on:

```gdscript
static func _requires(): return [Health, Damage]   # must have both
static func _optional(): return [Shield]            # included if present
static func _exclude(): return [Invincible]         # skip nodes with this
```

Node filters match the entity node itself and its children by type or name:

```gdscript
static func _require_nodes(): return [[StaticBody2D], ["Area"]]
static func _exclude_nodes(): return [["DebugOverlay"]]
```

### Runtime pipeline injection

Insert pipelines before or after existing stages, or attach result handlers that run based on pipeline outcome.

```gdscript
# Run ReverseDamagePipeline before DamagePipeline's deduct stage
Deus.inject_pipeline(ReverseDamagePipeline, DamagePipeline._stage_deduct, true)

# Execute a handler pipeline when DamagePipeline succeeds
Deus.inject_pipeline_result_handler(DamagePipeline, ResultPipeline, [PipelineResult.SUCCESS])

# Remove an injected pipeline
Deus.uninject_pipeline(ReverseDamagePipeline, DamagePipeline._stage_deduct)
```

### Editor configuration with DeusConfiguration

Add a `DeusConfiguration` child node to configure entities from the inspector without code. Components, resources, and signal-to-pipeline mappings are all configurable as exported arrays.

```
Player (StaticBody2D)
  DeusConfiguration
    node_id: "player_1"
    entity_config: EntityConfig (purge on destruction)
    components: [ComponentConfig(Health, value=100), ComponentConfig(Damage, value=10)]
    resources: [ResourceConfig(resource, "my_resource")]
    signals_to_pipelines: [SignalToPipelineConfig(pressed -> DamagePipeline, node_id: "player_1")]
```

### Signal-to-pipeline bridging

Wire Godot signals to pipeline execution. Target nodes by name, ID, path, or run globally against all matching entities.

```gdscript
# When button emits "pressed", execute DamagePipeline on target_node
Deus.signal_to_pipeline(button, "pressed", target_node, DamagePipeline)

# Execute on all matching entities globally
Deus.signal_to_global_pipeline(button, "pressed", DamagePipeline)
```

Signal connections use deferred handling with automatic retry, so target nodes don't need to exist in the tree at connection time.

### Scheduler phases

Register pipelines to run automatically in scheduler phases. Three phase groups map to Godot's processing hooks.

```gdscript
# Register a pipeline in the OnUpdate phase (runs every frame in _process)
Deus.pipeline_scheduler.register_task(PipelineSchedulerDefaults.OnUpdate, MyPipeline)

# Register with frequency (run every 0.5 seconds)
Deus.pipeline_scheduler.register_task(PipelineSchedulerDefaults.OnUpdate, SlowPipeline, 0.5)

# Register with priority (higher priority runs first)
Deus.pipeline_scheduler.register_task(PipelineSchedulerDefaults.OnUpdate, ImportantPipeline, 0.0, null, null, 10)
```

| Phase Group | Godot Hook | Phases |
|---|---|---|
| StartupPhase | `_process` (once) | PreStartup, OnStartup, PostStartup |
| DefaultPhase | `_process` (every frame) | ReservedPre, Init, PreUpdate, OnUpdate, PostUpdate, Final, ReservedPost |
| DefaultFixedPhase | `_physics_process` | ReservedPreFixed, InitFixed, PreFixedUpdate, OnFixedUpdate, PostFixedUpdate, FinalFixed, ReservedPostFixed |

All registration and deregistration is deferred - changes are queued and processed each frame. Deregistrations process before registrations to prevent conflicts.

### Node and resource registries

The node registry auto-tracks all nodes in the scene tree and provides multiple lookup methods.

```gdscript
# Look up nodes by name, type, ID, or group
var player = Deus.get_node_by_id("player_1")
var enemies = Deus.get_nodes_by_type("Enemy")
var ui_nodes = Deus.get_nodes_by_group("ui")

# Assign a custom ID to a node
Deus.set_node_id(my_node, "custom_id")

# Register and retrieve resources on nodes
Deus.register_resource(my_node, my_resource, "inventory")
var inv = Deus.get_resource(my_node, "inventory")
```

## Tech Stack

| Category | Technology |
|---|---|
| Engine | Godot 4.x |
| Language | GDScript |

## Roadmap

### Phase 1: MVP
- [x] Stable component registry with SparseSet storage
- [x] Pipeline execution with dependency injection and multi-stage support
- [x] Pipeline scheduler with phase groups (Startup, Default, DefaultFixed)
- [x] Component lifecycle signals
- [x] Signal-to-pipeline bridging
- [x] Pipeline injection with runtime overrides
- [x] Node and resource registries

### Phase 2: Post-Launch
- [ ] Entity and component serialisation
- [x] Breakout demo project - [deus-breakout](https://github.com/elgatopanzon/deus-breakout)
- [ ] GUI application demo project
- [ ] Performance optimisations and query caching
- [ ] Editor tooling and debugging tools
- [ ] Documentation, usage guides, and example pipelines
- [ ] Better Godot integration (physics sync, input routing, collision routing)
- [ ] Parallel pipeline execution and dependency graph

## License

MIT

## Completed Work

- **2026-01-31** - Breakout demo project (Godot Deus - P2 Post-Launch)
- **2026-01-10** - Pipeline scheduler with phase groups (Godot Deus - P1 MVP)
- **2026-01-10** - Pipeline execution with dependency injection and multi-stage support (Godot Deus - P1 MVP)
- **2026-01-10** - Stable component registry with SparseSet storage (Godot Deus - P1 MVP)
- **2026-01-10** - Pipeline injection with runtime overrides (Godot Deus - P1 MVP)
- **2026-01-10** - Signal-to-pipeline bridging (Godot Deus - P1 MVP)
- **2026-01-10** - Component lifecycle signals (Godot Deus - P1 MVP)
- **2026-01-09** - Node and resource registries (Godot Deus - P1 MVP)

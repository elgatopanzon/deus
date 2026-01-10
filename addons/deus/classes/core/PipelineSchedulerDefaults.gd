######################################################################
# @author      : ElGatoPanzon
# @class       : PipelineSchedulerDefaults
# @created     : Saturday Jan 10, 2026 14:47:55 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : default environment for the PipelineScheduler
######################################################################

class_name PipelineSchedulerDefaults

# phase groups
class StartupPhase: pass
class DefaultPhase: pass
class DefaultFixedPhase: pass

# startup phases
class PreStartup: pass
class OnStartup: pass
class PostStartup: pass

# default phases
class ReservedPre: pass
class Init: pass
class PreUpdate: pass
class OnUpdate: pass
class PostUpdate: pass
class Final: pass
class ReservedPost: pass

# default fixed phases
class ReservedPreFixed: pass
class InitFixed: pass
class PreFixedUpdate: pass
class OnFixedUpdate: pass
class PostFixedUpdate: pass
class FinalFixed: pass
class ReservedPostFixed: pass

static func init_default_environment(scheduler: PipelineScheduler):
	# startup phase
	scheduler.register_phase_group(StartupPhase)
	scheduler.register_phase(StartupPhase, PreStartup)
	scheduler.register_phase(StartupPhase, OnStartup)
	scheduler.register_phase(StartupPhase, PostStartup)

	# default variable tasks
	scheduler.register_phase(DefaultPhase, ReservedPre)
	scheduler.register_phase(DefaultPhase, Init)
	scheduler.register_phase(DefaultPhase, PreUpdate)
	scheduler.register_phase(DefaultPhase, OnUpdate)
	scheduler.register_phase(DefaultPhase, PostUpdate)
	scheduler.register_phase(DefaultPhase, Final)
	scheduler.register_phase(DefaultPhase, ReservedPost)

	# default fixed tasks
	scheduler.register_phase(DefaultFixedPhase, ReservedPreFixed)
	scheduler.register_phase(DefaultFixedPhase, InitFixed)
	scheduler.register_phase(DefaultFixedPhase, PreFixedUpdate)
	scheduler.register_phase(DefaultFixedPhase, OnFixedUpdate)
	scheduler.register_phase(DefaultFixedPhase, PostFixedUpdate)
	scheduler.register_phase(DefaultFixedPhase, FinalFixed)
	scheduler.register_phase(DefaultFixedPhase, ReservedPostFixed)

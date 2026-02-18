######################################################################
# @author      : ElGatoPanzon
# @class       : PipelineScheduler
# @created     : Saturday Jan 10, 2026 14:07:42 CST
# @copyright   : Copyright (c) ElGatoPanzon 2026
#
# @description : execute pipelines at regular intervals
######################################################################

# class name and base node
class_name PipelineScheduler
extends Node


# pipeline task inner class
class PipelineTask:
	var pipeline: Script
	var frequency: float = 0.0
	var last_run: float = 0.0
	var enabled: bool = true
	var priority: int = 0 # add priority to task

	func _init(_pipeline: Script, _frequency: float = 0.0, _priority: int = 0):
		pipeline = _pipeline
		frequency = _frequency
		last_run = 0.0
		enabled = true
		priority = _priority


var _world: DeusWorld

# phase groups: Script (group) -> Array of Script (phases)
var phase_groups: Dictionary = {}

# maps phase script -> task list
var tasks: Dictionary = {}

# per-phase and per-group scheduling control
var phase_scheduling_enabled: Dictionary = {}

# deferred queues for registration and deregistration, typed per operation
var _queued_reg_groups: Array = []
var _queued_reg_phases: Array = []
var _queued_reg_tasks: Array = []
var _queued_dereg_groups: Array = []
var _queued_dereg_phases: Array = []
var _queued_dereg_tasks: Array = []


func _init(world: DeusWorld):
	_world = world


func set_phase_scheduling_enabled(phase_or_group: Script, enabled: bool) -> void:
	phase_scheduling_enabled[phase_or_group] = enabled

func is_phase_scheduling_enabled(phase_or_group: Script) -> bool:
	return phase_scheduling_enabled.get(phase_or_group, true)


# phase group registration
func register_phase_group(group: Script):
	_queued_reg_groups.append(group)

func get_group_phases(group: Script) -> Array:
	return phase_groups.get(group, [])

# phase registration
func register_phase(group: Script, phase: Script, before = null, after = null) -> void:
	_queued_reg_phases.append([group, phase, before, after])

# task registration
func register_task(phase: Script, pipeline: Script, frequency: float = 0.0, before = null, after = null, priority: int = 0) -> void:
	_queued_reg_tasks.append([phase, pipeline, frequency, before, after, priority])

# task deregistration
func deregister_task(phase: Script, pipeline: Script) -> void:
	_queued_dereg_tasks.append([phase, pipeline])

# phase deregistration
func deregister_phase(group: Script, phase: Script) -> void:
	_queued_dereg_phases.append([group, phase])

# phase group deregistration
func deregister_phase_group(group: Script) -> void:
	_queued_dereg_groups.append(group)


# executes all deferred registrations and deregistrations
func _process(_delta: float) -> void:
	if not _queued_dereg_tasks.is_empty() or not _queued_dereg_phases.is_empty() or not _queued_dereg_groups.is_empty():
		_process_deregistrations()
	if not _queued_reg_groups.is_empty() or not _queued_reg_phases.is_empty() or not _queued_reg_tasks.is_empty():
		_process_registrations()

# process all queued deregistrations first
func _process_deregistrations() -> void:
	for d in _queued_dereg_tasks:
		_immediate_deregister_task(d[0], d[1])
	_queued_dereg_tasks.clear()
	for d in _queued_dereg_phases:
		_immediate_deregister_phase(d[0], d[1])
	_queued_dereg_phases.clear()
	for d in _queued_dereg_groups:
		_immediate_deregister_phase_group(d)
	_queued_dereg_groups.clear()

# process all queued registrations after
func _process_registrations() -> void:
	for r in _queued_reg_groups:
		_immediate_register_phase_group(r)
	_queued_reg_groups.clear()
	for r in _queued_reg_phases:
		_immediate_register_phase(r[0], r[1], r[2], r[3])
	_queued_reg_phases.clear()
	for r in _queued_reg_tasks:
		_immediate_register_task(r[0], r[1], r[2], r[3], r[4], r[5])
	_queued_reg_tasks.clear()


# immediate phase group registration logic
func _immediate_register_phase_group(group: Script):
	if not phase_groups.has(group):
		phase_groups[group] = []
		set_phase_scheduling_enabled(group, true)

# immediate phase registration logic
func _immediate_register_phase(group: Script, phase: Script, before = null, after = null) -> void:
	_immediate_register_phase_group(group)
	var phase_list = phase_groups[group]
	# Only allow the phase to be registered once per group
	if phase in phase_list:
		return
	if before != null and before in phase_list:
		phase_list.insert(phase_list.find(before), phase)
	elif after != null and after in phase_list:
		phase_list.insert(phase_list.find(after) + 1, phase)
	else:
		phase_list.append(phase)
	set_phase_scheduling_enabled(phase, true)

# immediate task registration logic
func _immediate_register_task(phase: Script, pipeline: Script, frequency: float = 0.0, before = null, after = null, priority: int = 0) -> void:
	if not tasks.has(phase):
		tasks[phase] = []
	var task_list = tasks[phase]

	# only allow the task to be registered once
	for t in task_list:
		if t.pipeline == pipeline:
			return

	var task = PipelineTask.new(pipeline, frequency, priority)

	if before != null:
		for i in range(task_list.size()):
			if task_list[i].pipeline == before:
				task_list.insert(i, task)
				return
	if after != null:
		for i in range(task_list.size()):
			if task_list[i].pipeline == after:
				task_list.insert(i + 1, task)
				return

	_sorted_insert(task_list, task)

# immediate task deregistration logic
func _immediate_deregister_task(phase: Script, pipeline: Script) -> void:
	if tasks.has(phase):
		var task_list = tasks[phase]
		for i in range(task_list.size()):
			if task_list[i].pipeline == pipeline:
				task_list.remove_at(i)
				break
		# remove the phase entry if no tasks left
		if task_list.is_empty():
			tasks.erase(phase)

# immediate phase deregistration logic
func _immediate_deregister_phase(group: Script, phase: Script) -> void:
	if phase_groups.has(group):
		phase_groups[group].erase(phase)
		# remove the group's entry if empty
		if phase_groups[group].is_empty():
			phase_groups.erase(group)
	# also deregister any associated tasks
	if tasks.has(phase):
		tasks.erase(phase)
	# disable scheduling for this phase as well
	if phase_scheduling_enabled.has(phase):
		phase_scheduling_enabled.erase(phase)

# immediate phase group deregistration logic (recursive)
func _immediate_deregister_phase_group(group: Script) -> void:
	if phase_groups.has(group):
		for phase in phase_groups[group]:
			# recursively deregister sub-phases
			if phase_groups.has(phase):
				_immediate_deregister_phase_group(phase)
			else:
				# just remove the phase's tasks
				if tasks.has(phase):
					tasks.erase(phase)
				if phase_scheduling_enabled.has(phase):
					phase_scheduling_enabled.erase(phase)
		phase_groups.erase(group)
	# also remove any direct tasks attached to this group
	if tasks.has(group):
		tasks.erase(group)
	if phase_scheduling_enabled.has(group):
		phase_scheduling_enabled.erase(group)


# binary search insert maintaining priority descending order (higher = earlier)
func _sorted_insert(task_list: Array, task: PipelineTask) -> void:
	var lo := 0
	var hi := task_list.size()
	var p := task.priority
	while lo < hi:
		var mid := (lo + hi) >> 1
		if task_list[mid].priority >= p:
			lo = mid + 1
		else:
			hi = mid
	task_list.insert(lo, task)


func run_tasks(group: Script, delta: float) -> void:
	_world.delta = delta
	var now := Time.get_ticks_msec() / 1000.0
	_run_scheduled_tasks(group, now)

func run_tasks_now(phase: Script) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for task in tasks.get(phase, []):
		if task.enabled:
			_world.execute_global_pipeline(task.pipeline)
			task.last_run = now
	for subphase in phase_groups.get(phase, []):
		run_tasks_now(subphase)


# runs scheduled tasks recursively for phases and phase groups
func _run_scheduled_tasks(phase_or_group: Script, now: float) -> void:
	if not is_phase_scheduling_enabled(phase_or_group):
		return

	# run tasks attached to this phase/group
	for task in tasks.get(phase_or_group, []):
		if not task.enabled:
			continue
		if task.frequency == 0.0 or (now - task.last_run) >= task.frequency:
			_world.execute_global_pipeline(task.pipeline)
			task.last_run = now

	# recursively run tasks for sub-phases,
	# but only if scheduling is enabled for that subphase/group
	for subphase in phase_groups.get(phase_or_group, []):
		_run_scheduled_tasks(subphase, now)

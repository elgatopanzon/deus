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

# deferred queues for registration and deregistration
var _queued_registrations: Array = []
var _queued_deregistrations: Array = []


func _init(world: DeusWorld):
	_world = world


func set_phase_scheduling_enabled(phase_or_group: Script, enabled: bool) -> void:
	phase_scheduling_enabled[phase_or_group] = enabled

func is_phase_scheduling_enabled(phase_or_group: Script) -> bool:
	return phase_scheduling_enabled.get(phase_or_group, true)


# phase group registration
func register_phase_group(group: Script):
	_queued_registrations.append({
		"type": "group",
		"group": group
	})

func get_group_phases(group: Script) -> Array:
	return phase_groups.get(group, [])

# phase registration
func register_phase(group: Script, phase: Script, before = null, after = null) -> void:
	_queued_registrations.append({
		"type": "phase",
		"group": group,
		"phase": phase,
		"before": before,
		"after": after
	})

# task registration
func register_task(phase: Script, pipeline: Script, frequency: float = 0.0, before = null, after = null, priority: int = 0) -> void:
	_queued_registrations.append({
		"type": "task",
		"phase": phase,
		"pipeline": pipeline,
		"frequency": frequency,
		"before": before,
		"after": after,
		"priority": priority
	})

# task deregistration
func deregister_task(phase: Script, pipeline: Script) -> void:
	_queued_deregistrations.append({
		"type": "task",
		"phase": phase,
		"pipeline": pipeline
	})

# phase deregistration
func deregister_phase(group: Script, phase: Script) -> void:
	_queued_deregistrations.append({
		"type": "phase",
		"group": group,
		"phase": phase
	})

# phase group deregistration
func deregister_phase_group(group: Script) -> void:
	_queued_deregistrations.append({
		"type": "group",
		"group": group
	})


# executes all deferred registrations and deregistrations
func _process(_delta: float) -> void:
	_process_deregistrations()
	_process_registrations()

# process all queued deregistrations first
func _process_deregistrations() -> void:
	for d in _queued_deregistrations:
		match d.type:
			"task":
				_immediate_deregister_task(d.phase, d.pipeline)
			"phase":
				_immediate_deregister_phase(d.group, d.phase)
			"group":
				_immediate_deregister_phase_group(d.group)
	_queued_deregistrations.clear()

# process all queued registrations after
func _process_registrations() -> void:
	for r in _queued_registrations:
		match r.type:
			"group":
				_immediate_register_phase_group(r.group)
			"phase":
				_immediate_register_phase(r.group, r.phase, r.before, r.after)
			"task":
				_immediate_register_task(r.phase, r.pipeline, r.frequency, r.before, r.after, r.priority)
	_queued_registrations.clear()


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
		for i in range(len(task_list)):
			if task_list[i].pipeline == before:
				task_list.insert(i, task)
				_sort_tasks_by_priority(task_list)
				return
	if after != null:
		for i in range(len(task_list)):
			if task_list[i].pipeline == after:
				task_list.insert(i + 1, task)
				_sort_tasks_by_priority(task_list)
				return

	task_list.append(task)
	_sort_tasks_by_priority(task_list)

# immediate task deregistration logic
func _immediate_deregister_task(phase: Script, pipeline: Script) -> void:
	if tasks.has(phase):
		var task_list = tasks[phase]
		for i in range(len(task_list)):
			if task_list[i].pipeline == pipeline:
				task_list.remove(i)
				break
		# remove the phase entry if no tasks left
		if task_list.empty():
			tasks.erase(phase)

# immediate phase deregistration logic
func _immediate_deregister_phase(group: Script, phase: Script) -> void:
	if phase_groups.has(group):
		phase_groups[group].erase(phase)
		# remove the group's entry if empty
		if phase_groups[group].empty():
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


# helper to sort by priority descending (higher = earlier)
func _sort_tasks_by_priority(task_list: Array) -> void:
	task_list.sort_custom(_sort_priority)

func _sort_priority(a, b):
	# first, compare by priority descending
	if a.priority > b.priority:
		return -1
	elif a.priority < b.priority:
		return 1
	return 0


func run_tasks(group: Script, delta: float) -> void:
	_world.delta = delta
	_run_scheduled_tasks(group)

func run_tasks_now(phase: Script) -> void:
	for task in tasks.get(phase, []):
		if task.enabled:
			_world.execute_global_pipeline(task.pipeline)
			task.last_run = Time.get_ticks_msec() / 1000.0
	for subphase in phase_groups.get(phase, []):
		run_tasks_now(subphase)


# runs scheduled tasks recursively for phases and phase groups
func _run_scheduled_tasks(phase_or_group: Script) -> void:
	if not is_phase_scheduling_enabled(phase_or_group):
		return

	var now = Time.get_ticks_msec() / 1000.0

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
		_run_scheduled_tasks(subphase)

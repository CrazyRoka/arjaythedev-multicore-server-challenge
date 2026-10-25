package main

import "base:runtime"

import "core:mem/virtual"

worker_loop :: proc(w: ^Worker) {
	for {
		job := queue_pop(&g_app.queue)
		if job == nil {
			return
		}

		context.temp_allocator = virtual.arena_allocator(&w.temp)
		handle_job(w, job)
		free_all(context.temp_allocator)
		free(job, runtime.heap_allocator())
	}
}

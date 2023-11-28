package sandbox

import "core:fmt"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"
import "core:runtime"

main :: proc() {
	arena: virtual.Arena
	// arena_buffer: [4 * mem.Kilobyte]byte
	arena_buffer: [256]byte
	arena_init_error := virtual.arena_init_buffer(&arena, arena_buffer[:])
	if arena_init_error != nil {
		fmt.panicf("Error initializing arena: %v\n", arena_init_error)
	}
	arena_allocator := virtual.arena_allocator(&arena)
	defer virtual.arena_destroy(&arena)
	// context.allocator = runtime.default_allocator

	log_file_handle, log_file_open_error := os.open("log.txt", os.O_WRONLY)
	context.allocator = arena_allocator
	context.logger = log.create_multi_logger(
		log.create_console_logger(),
		log.create_file_logger(log_file_handle),
	)
	config, err := read_configuration("file1.txt", Once{}, "url")
	if err != nil {
		fmt.panicf("Error reading configuration file: %v\n", err)
	}

	fmt.printf("Configuration: %v\n", config)
}

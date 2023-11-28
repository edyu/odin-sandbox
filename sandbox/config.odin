package sandbox

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:testing"

Configuration :: struct {
	filename: string,
	interval: Interval,
	url:      string,
}

ConfigurationJson :: struct {
	filename: string,
	interval: string,
	url:      string,
}

Interval :: union {
	Never,
	Once,
	EveryMilliseconds,
}

Never :: struct {}

Once :: struct {}

EveryMilliseconds :: struct {
	interval: int,
}

ParsingError :: union {
	InvalidSyntax,
	InvalidValue,
	json.Unmarshal_Error,
	json.Error,
}

InvalidSyntax :: struct {
	line:   int,
	column: int,
	data:   []byte,
}

InvalidValue :: struct {
	line:   int,
	column: int,
	data:   []byte,
	value:  json.Value,
	field:  string,
}

ConfigurationError :: union {
	ParsingError,
	FileReadFailed,
	mem.Allocator_Error,
}

FileReadFailed :: struct {
	filename: string,
}

parse_configuration :: proc(data: []byte) -> (config: Configuration, err: ParsingError) {
	/*
	json_config: ConfigurationJson
	json.unmarshal(data, &json_config) or_return

	config.filename = json_config.filename
	config.url = json_config.url

	switch json_config.interval {
	case "never":
		config.interval = Never{}
	case "once":
		config.interval = Once{}
	case:
		i, parse_success := strconv.parse_int(json_config.interval)
		if parse_success {
			config.interval = EveryMilliseconds {
				interval = i,
			}
		}
	}
	*/
	json_value := json.parse(data) or_return
	object, is_object := json_value.(json.Object)
	if !is_object {
		return Configuration{}, InvalidValue{value = json_value}
	}

	filename, filename_is_string := object["filename"].(json.String)
	if !filename_is_string && object["filename"] != nil {
		return Configuration{}, InvalidValue{field = "filename", value = object["filename"]}
	}
	config.filename = filename

	url, url_is_string := object["url"].(json.String)
	if !url_is_string && object["url"] != nil {
		return Configuration{}, InvalidValue{field = "url", value = object["url"]}
	}
	config.url = url

	interval: Interval
	interval_value, interval_is_string := object["interval"].(json.String)
	interval_int, interval_is_int := object["interval"].(json.Integer)
	if interval_is_string {
		switch interval_value {
		case "never":
			interval = Never{}
		case "once":
			interval = Once{}
		case:
			return Configuration{}, InvalidValue{field = "interval", value = object["interval"]}
		}
	} else if interval_is_int {
		interval = EveryMilliseconds {
			interval = int(interval_int),
		}
	} else if object["interval"] != nil {
		return Configuration{}, InvalidValue{field = "interval", value = object["interval"]}
	}
	config.interval = interval

	return config, nil
}

@(test)
test_parse_configuration :: proc(t: ^testing.T) {
	expected := Configuration{}
	actual, parsing_error := parse_configuration([]byte{'{', '}'})
	// actual, parsing_error := parse_configuration([]byte{})
	testing.expect(t, expected == actual, fmt.tprintf("Expected %v, got %v", expected, actual))
	testing.expect(
		t,
		parsing_error == nil,
		fmt.tprintf("Expected no parsing error, got %v", parsing_error),
	)

	expected2 := Configuration {
		filename = "some_filename.txt",
		interval = Once{},
		url = "https://example.com/",
	}
	data2 := transmute([]byte)string(
		`{"filename": "some_filename.txt", "interval": "once", "url": "https://example.com/"}`,
	)
	actual2, parsing_error2 := parse_configuration(data2)
	testing.expect(t, expected2 == actual2, fmt.tprintf("Expected %v, got %v", expected2, actual2))
	testing.expect(
		t,
		parsing_error2 == nil,
		fmt.tprintf("Expected no parsing error, got %v", parsing_error2),
	)
}

read_configuration :: proc(
	filename: string,
	interval: Interval,
	url: string,
	allocator := context.allocator,
) -> (
	config: Configuration,
	err: ConfigurationError,
) {
	config.filename = filename
	config.interval = interval

	switch i in interval {
	case Never, Once:
		fmt.printf("never or once: %v\n", i)
	case EveryMilliseconds:
		fmt.printf("every: %v\n", i)
	}

	if every, is_every_milliseconds := interval.(EveryMilliseconds); is_every_milliseconds {
		fmt.printf("every milliseconds: %v\n", every)
	}

	file_data, read_was_successful := os.read_entire_file_from_filename(filename, allocator)
	if !read_was_successful {
		return Configuration{}, FileReadFailed{filename = filename}
	}

	parsed_config := parse_configuration(file_data) or_return
	log.debugf("Parsed config: %v\n", parsed_config)
	parsed_config.url = strings.concatenate({"prefix://", parsed_config.url}, allocator) or_return

	return parsed_config, nil
}

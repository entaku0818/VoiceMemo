package main

import (
	"reflect"
	"testing"
)

func TestParseMinutes(t *testing.T) {
	tests := []struct {
		name string
		raw  string
		want minutesResult
	}{
		{
			name: "plain JSON",
			raw:  `{"summary":"要約です","todos":["TODO1","TODO2"]}`,
			want: minutesResult{Summary: "要約です", Todos: []string{"TODO1", "TODO2"}},
		},
		{
			name: "markdown fenced JSON",
			raw:  "```json\n{\"summary\":\"要約\",\"todos\":[]}\n```",
			want: minutesResult{Summary: "要約", Todos: []string{}},
		},
		{
			name: "JSON with surrounding prose",
			raw:  "はい、こちらが議事録です。\n{\"summary\":\"会議の要約\",\"todos\":[\"資料送付\"]}\nご確認ください。",
			want: minutesResult{Summary: "会議の要約", Todos: []string{"資料送付"}},
		},
		{
			name: "todos omitted becomes empty slice",
			raw:  `{"summary":"要約のみ"}`,
			want: minutesResult{Summary: "要約のみ", Todos: []string{}},
		},
		{
			name: "unparseable falls back to raw text as summary",
			raw:  "  JSONではないただのテキスト  ",
			want: minutesResult{Summary: "JSONではないただのテキスト", Todos: []string{}},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseMinutes(tt.raw)
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("parseMinutes() = %+v, want %+v", got, tt.want)
			}
		})
	}
}

func TestTruncateRunes(t *testing.T) {
	if got := truncateRunes("あいうえお", 3); got != "あいう" {
		t.Errorf("truncateRunes multibyte = %q, want %q", got, "あいう")
	}
	if got := truncateRunes("short", 100); got != "short" {
		t.Errorf("truncateRunes short = %q, want %q", got, "short")
	}
}

func TestExtractJSON(t *testing.T) {
	raw := "```json\n{\"a\":1}\n```"
	if got := extractJSON(raw); got != `{"a":1}` {
		t.Errorf("extractJSON = %q", got)
	}
}

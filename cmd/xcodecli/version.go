package main

import "strings"

var cliVersion = "dev"

func currentVersion() string {
	version := strings.TrimSpace(cliVersion)
	if version == "" {
		return "dev"
	}
	return version
}

func versionLine() string {
	return "xcodecli " + currentVersion()
}

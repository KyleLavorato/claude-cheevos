package subcmd

import "fmt"

// Version prints the embedded application version to stdout.
func Version(appVersion string) error {
	fmt.Println(appVersion)
	return nil
}

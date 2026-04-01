package subcmd

import (
	"fmt"

	"github.com/user/claude-cheevos/internal/store"
)

// GetCounter outputs the integer value of a named counter from the encrypted state.
// Outputs "0" if the state cannot be loaded or the counter does not exist.
// Usage: cheevos get-counter <counter-name>
func GetCounter(achievementsDir string, args []string, key [32]byte) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: get-counter <counter-name>")
	}
	counterName := args[0]
	stateFile := achievementsDir + "/state.json"
	st, err := store.NewEncryptedJSONStore(stateFile, key).Load()
	if err != nil {
		fmt.Println("0")
		return nil //nolint:nilerr
	}
	fmt.Println(st.Counters[counterName])
	return nil
}

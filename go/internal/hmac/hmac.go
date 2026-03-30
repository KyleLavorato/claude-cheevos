package hmac

import (
    "crypto/hmac"
    "crypto/sha256"
    "encoding/base64"
    "errors"
    "fmt"
    "strconv"
    "time"
)

const (
    // MaxAge is the maximum age of a signed payload before it is rejected.
    // Prevents replay attacks where an old valid signature is reused.
    MaxAge = 10 * time.Second
)

// Sign computes HMAC-SHA256 of the hook payload and returns a base64-encoded signature.
// This mirrors the shell-side cheevos_sign() function in lib.sh.
func Sign(secret []byte, counterUpdates, counterSets, newModel, sessionID, tsStr string) string {
    payload := buildPayload(counterUpdates, counterSets, newModel, sessionID, tsStr)
    mac := hmac.New(sha256.New, secret)
    mac.Write([]byte(payload))
    return base64.StdEncoding.EncodeToString(mac.Sum(nil))
}

// Verify checks that sig is a valid HMAC-SHA256 signature of the hook payload,
// and that the timestamp is within MaxAge of now.
func Verify(secret []byte, counterUpdates, counterSets, newModel, sessionID, tsStr, sig string) error {
    if tsStr == "" {
        return errors.New("hmac: missing _CHEEVOS_TS")
    }
    if sig == "" {
        return errors.New("hmac: missing _CHEEVOS_SIG")
    }

    tsNs, err := strconv.ParseInt(tsStr, 10, 64)
    if err != nil {
        return fmt.Errorf("hmac: invalid timestamp %q: %w", tsStr, err)
    }
    nowNs := time.Now().UnixNano()
    diff := nowNs - tsNs
    if diff < 0 {
        diff = -diff
    }
    if diff > int64(MaxAge) {
        return fmt.Errorf("hmac: timestamp out of window (%v old, max %v)", time.Duration(diff), MaxAge)
    }

    expected := Sign(secret, counterUpdates, counterSets, newModel, sessionID, tsStr)
    if !hmac.Equal([]byte(expected), []byte(sig)) {
        return errors.New("hmac: signature mismatch")
    }
    return nil
}

func buildPayload(counterUpdates, counterSets, newModel, sessionID, tsStr string) string {
    sep := "\x00"
    return counterUpdates + sep + counterSets + sep + newModel + sep + sessionID + sep + tsStr
}

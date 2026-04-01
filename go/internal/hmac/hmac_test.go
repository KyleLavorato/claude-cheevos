package hmac

import (
    "fmt"
    "strconv"
    "testing"
    "time"
)

var testSecret = []byte("test-hmac-secret-32bytes-exactly")

func TestVerifyValidSignature(t *testing.T) {
    ts := strconv.FormatInt(time.Now().UnixNano(), 10)
    sig := Sign(testSecret, `{"bash_calls":1}`, "", ts)

    if err := Verify(testSecret, `{"bash_calls":1}`, "", ts, sig); err != nil {
        t.Fatalf("expected valid signature to pass: %v", err)
    }
}

func TestVerifyWrongSignatureFails(t *testing.T) {
    ts := strconv.FormatInt(time.Now().UnixNano(), 10)
    sig := Sign(testSecret, `{"bash_calls":1}`, "", ts)

    // Tamper with counter value.
    err := Verify(testSecret, `{"bash_calls":9999}`, "", ts, sig)
    if err == nil {
        t.Fatal("expected tampered payload to fail HMAC verification")
    }
}

func TestVerifyStaleTimestampFails(t *testing.T) {
    staleNs := time.Now().Add(-30 * time.Second).UnixNano()
    ts := strconv.FormatInt(staleNs, 10)
    sig := Sign(testSecret, `{"bash_calls":1}`, "", ts)

    err := Verify(testSecret, `{"bash_calls":1}`, "", ts, sig)
    if err == nil {
        t.Fatal("expected stale timestamp to fail replay protection")
    }
}

func TestVerifyFutureTimestampFails(t *testing.T) {
    futureNs := time.Now().Add(30 * time.Second).UnixNano()
    ts := strconv.FormatInt(futureNs, 10)
    sig := Sign(testSecret, `{"bash_calls":1}`, "", ts)

    err := Verify(testSecret, `{"bash_calls":1}`, "", ts, sig)
    if err == nil {
        t.Fatal("expected future timestamp to fail replay protection")
    }
}

func TestVerifyMissingTsFails(t *testing.T) {
    err := Verify(testSecret, `{}`, "", "", "somesig")
    if err == nil {
        t.Fatal("expected missing timestamp to fail")
    }
}

func TestVerifyMissingSigFails(t *testing.T) {
    ts := strconv.FormatInt(time.Now().UnixNano(), 10)
    err := Verify(testSecret, `{}`, "", ts, "")
    if err == nil {
        t.Fatal("expected missing sig to fail")
    }
}

func TestSignIncludesAllFields(t *testing.T) {
    ts := strconv.FormatInt(time.Now().UnixNano(), 10)
    // Signatures differing only in counter_sets must differ.
    sig1 := Sign(testSecret, `{"a":1}`, `{"streak_days":1}`, ts)
    sig2 := Sign(testSecret, `{"a":1}`, `{"streak_days":2}`, ts)
    if sig1 == sig2 {
        t.Fatal("signatures differing only in counter_sets should differ")
    }

    // Verify full round-trip with both fields populated.
    if err := Verify(testSecret, `{"a":1}`, `{"streak_days":1}`, ts, sig1); err != nil {
        t.Fatalf("full-field verify: %v", err)
    }
    fmt.Println("all HMAC tests passed")
}

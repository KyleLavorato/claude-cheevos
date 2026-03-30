package crypto

import (
    "bytes"
    "testing"
)

func TestEncryptDecryptRoundTrip(t *testing.T) {
    var key [32]byte
    copy(key[:], "test-key-32-bytes-exactly-padded")

    plaintext := []byte(`{"score":42,"counters":{"sessions":10}}`)

    nonce, ciphertext, err := Encrypt(key, plaintext)
    if err != nil {
        t.Fatalf("Encrypt: %v", err)
    }
    if len(nonce) == 0 || len(ciphertext) == 0 {
        t.Fatal("expected non-empty nonce and ciphertext")
    }

    recovered, err := Decrypt(key, nonce, ciphertext)
    if err != nil {
        t.Fatalf("Decrypt: %v", err)
    }
    if !bytes.Equal(recovered, plaintext) {
        t.Fatalf("round-trip mismatch:\n  got  %s\n  want %s", recovered, plaintext)
    }
}

func TestEncryptProducesFreshNonceEachCall(t *testing.T) {
    var key [32]byte
    plaintext := []byte("same plaintext")

    n1, _, _ := Encrypt(key, plaintext)
    n2, _, _ := Encrypt(key, plaintext)
    if bytes.Equal(n1, n2) {
        t.Fatal("expected different nonces on each Encrypt call")
    }
}

func TestDecryptWrongKeyFails(t *testing.T) {
    var key [32]byte
    copy(key[:], "correct-key-32-bytes-exactly!!!")

    nonce, ciphertext, _ := Encrypt(key, []byte("secret"))

    var wrongKey [32]byte
    copy(wrongKey[:], "wrong---key-32-bytes-exactly!!!!")
    _, err := Decrypt(wrongKey, nonce, ciphertext)
    if err == nil {
        t.Fatal("expected decryption to fail with wrong key")
    }
}

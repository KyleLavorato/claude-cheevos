package crypto

import (
    "crypto/aes"
    "crypto/cipher"
    "crypto/rand"
    "fmt"
    "io"
)

// Encrypt encrypts plaintext with AES-256-GCM using the provided key.
// Returns (nonce, ciphertext+tag, error). A fresh random nonce is generated per call.
func Encrypt(key [32]byte, plaintext []byte) (nonce []byte, ciphertext []byte, err error) {
    block, err := aes.NewCipher(key[:])
    if err != nil {
        return nil, nil, fmt.Errorf("crypto: aes.NewCipher: %w", err)
    }
    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return nil, nil, fmt.Errorf("crypto: cipher.NewGCM: %w", err)
    }

    nonce = make([]byte, gcm.NonceSize())
    if _, err = io.ReadFull(rand.Reader, nonce); err != nil {
        return nil, nil, fmt.Errorf("crypto: nonce generation: %w", err)
    }

    ciphertext = gcm.Seal(nil, nonce, plaintext, nil)
    return nonce, ciphertext, nil
}

// Decrypt decrypts AES-256-GCM ciphertext (including tag) using the provided key and nonce.
func Decrypt(key [32]byte, nonce, ciphertext []byte) ([]byte, error) {
    block, err := aes.NewCipher(key[:])
    if err != nil {
        return nil, fmt.Errorf("crypto: aes.NewCipher: %w", err)
    }
    gcm, err := cipher.NewGCM(block)
    if err != nil {
        return nil, fmt.Errorf("crypto: cipher.NewGCM: %w", err)
    }
    plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
    if err != nil {
        return nil, fmt.Errorf("crypto: decryption failed (wrong key or corrupt data): %w", err)
    }
    return plaintext, nil
}

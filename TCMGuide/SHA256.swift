//
//  SHA256.swift
//  TCMGuide
//
//  Created by Kevin Fan on 2022/11/22.
//  Copyright © 2022 Dobrinka Tabakova. All rights reserved.
//

import Foundation
import CommonCrypto

private
    struct AESCrypt {
        private let key: Data
        private let ivSize: Int = kCCBlockSizeAES128
        private let options: CCOptions = CCOptions(kCCOptionPKCS7Padding)

        init(key: Data) throws {
            guard key.count == kCCKeySizeAES256 else {
                throw Error.invalidKeySize
            }
            self.key = key
        }
    }

private
    extension AESCrypt {
        enum Error: Swift.Error {
            case invalidKeySize
            case generateRandomIVFailed
            case encryptionFailed
            case decryptionFailed
            case dataToStringFailed
        }
    }

private
    extension AESCrypt {

        func generateRandomIV(for data: inout Data) throws {

            try data.withUnsafeMutableBytes { dataBytes in
                guard let dataBytesBaseAddress = dataBytes.baseAddress else {
                    throw Error.generateRandomIVFailed
                }

                let status: Int32 = SecRandomCopyBytes(
                    kSecRandomDefault,
                    kCCBlockSizeAES128,
                    dataBytesBaseAddress
                )

                guard status == 0 else {
                    throw Error.generateRandomIVFailed
                }
            }
        }
    }

private
    extension AESCrypt {

        func encrypt(_ string: String) throws -> Data {
            let data = Data(string.utf8)
            return try encrypt(data)
        }
        
        func encrypt(_ data: Data) throws -> Data {

            let bufferSize: Int = ivSize + data.count + kCCBlockSizeAES128
            var buffer = Data(count: bufferSize)
            try generateRandomIV(for: &buffer)

            var numberBytesEncrypted: Int = 0

            do {
                try key.withUnsafeBytes { keyBytes in
                    try data.withUnsafeBytes { dataToEncryptBytes in
                        try buffer.withUnsafeMutableBytes { bufferBytes in

                            guard let keyBytesBaseAddress = keyBytes.baseAddress,
                                let dataToEncryptBytesBaseAddress = dataToEncryptBytes.baseAddress,
                                let bufferBytesBaseAddress = bufferBytes.baseAddress else {
                                    throw Error.encryptionFailed
                            }

                            let cryptStatus: CCCryptorStatus = CCCrypt(
                                CCOperation(kCCEncrypt),
                                CCAlgorithm(kCCAlgorithmAES),
                                options,
                                keyBytesBaseAddress,
                                key.count,
                                bufferBytesBaseAddress,
                                dataToEncryptBytesBaseAddress,
                                dataToEncryptBytes.count,
                                bufferBytesBaseAddress + ivSize,
                                bufferSize,
                                &numberBytesEncrypted
                            )

                            guard cryptStatus == CCCryptorStatus(kCCSuccess) else {
                                throw Error.encryptionFailed
                            }
                        }
                    }
                }

            } catch {
                throw Error.encryptionFailed
            }

            let encryptedData: Data = buffer[..<(numberBytesEncrypted + ivSize)]
            return encryptedData
        }
    }

private
    extension AESCrypt {

        func decrypt(_ data: Data) throws -> Data {

            let bufferSize: Int = data.count - ivSize
            var buffer = Data(count: bufferSize)

            var numberBytesDecrypted: Int = 0

            do {
                try key.withUnsafeBytes { keyBytes in
                    try data.withUnsafeBytes { dataToDecryptBytes in
                        try buffer.withUnsafeMutableBytes { bufferBytes in

                            guard let keyBytesBaseAddress = keyBytes.baseAddress,
                                let dataToDecryptBytesBaseAddress = dataToDecryptBytes.baseAddress,
                                let bufferBytesBaseAddress = bufferBytes.baseAddress else {
                                    throw Error.encryptionFailed
                            }

                            let cryptStatus: CCCryptorStatus = CCCrypt(
                                CCOperation(kCCDecrypt),
                                CCAlgorithm(kCCAlgorithmAES128),
                                options,
                                keyBytesBaseAddress,
                                key.count,
                                dataToDecryptBytesBaseAddress,
                                dataToDecryptBytesBaseAddress + ivSize,
                                bufferSize,
                                bufferBytesBaseAddress,
                                bufferSize,
                                &numberBytesDecrypted
                            )

                            guard cryptStatus == CCCryptorStatus(kCCSuccess) else {
                                throw Error.decryptionFailed
                            }
                        }
                    }
                }
            } catch {
                throw Error.encryptionFailed
            }

            let decryptedData: Data = buffer[..<numberBytesDecrypted]
            return decryptedData
/*
            guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
                throw Error.dataToStringFailed
            }

            return decryptedString
 */
        }
    }

extension String {

    func aesEncrypted(_key: String)-> Data? {
        let key = Data(_key.utf8)
        let aes = try? AESCrypt(key: key)
        return try! aes?.encrypt(self)
    }

  }


extension Data {

    func aesEncrypted(_key: String) throws -> Data? {
       let key = Data(_key.utf8)
       let aes = try? AESCrypt(key: key)
       return try! aes?.encrypt(self)
   }

   func aesDecrypted(_key: String) throws -> Data? {
       let key = Data(_key.utf8)
       let aes = try? AESCrypt(key: key)
       return try! aes?.decrypt(self)
   }

 }

//
//  DataHex.swift
//  PDFKitSample
//
//  Created by Kevin Fan on 2022/11/22.
//  Copyright © 2022 Dobrinka Tabakova. All rights reserved.
//

import Foundation

extension Data {
    func hexString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}

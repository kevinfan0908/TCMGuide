//
//  MyPDFView.swift
//  PDFKitSample
//
//  Created by Kevin Fan on 2022/11/26.
//  Copyright © 2022 Dobrinka Tabakova. All rights reserved.
//

import Foundation
import PDFKit

class MyPDFView: PDFView {

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        /*
        if action == #selector(UIResponderStandardEditActions.paste(_:)) || action == #selector(UIResponderStandardEditActions.copy(_:)) {
                    return false
                }
               
                return super.canPerformAction(action, withSender: sender)
         */
        return false;
    }

    override func addGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer is UILongPressGestureRecognizer 
        || gestureRecognizer is UIPanGestureRecognizer || gestureRecognizer is UIPanGestureRecognizer || gestureRecognizer is UIPinchGestureRecognizer{
            gestureRecognizer.isEnabled = false
        }

        super.addGestureRecognizer(gestureRecognizer)
    }

}

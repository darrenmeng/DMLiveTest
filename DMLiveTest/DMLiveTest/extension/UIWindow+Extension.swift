//
//  ViewController+Extension.swift
//  DMLiveTest
//
//  Created by darrenChiang on 2018/3/19.
//  Copyright © 2018年 darrenChiang. All rights reserved.
//

import UIKit

extension UIWindow  {

    class func topViewController() -> UIViewController? {
        if var topController = UIApplication.shared.keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            return topController
        }
        return nil
    }
}

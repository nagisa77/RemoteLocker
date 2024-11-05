//
//  RemoteLockerApp.swift
//  RemoteLocker
//
//  Created by tim on 2024/10/14.
//

import SwiftUI

@main
struct RemoteLockerApp: App {
  // 通过 @NSApplicationDelegateAdaptor 使用自定义的 AppDelegate
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
  var body: some Scene {
    EmptyScene()
  }
}

struct EmptyScene: Scene {
  var body: some Scene {
    WindowGroup {
      EmptyView()
    }
  }
}

//
//  AppDelegate.swift
//  RemoteLocker
//
//  Created by tim on 2024/10/14.
//

import Cocoa
import SwiftUI
import FirebaseCore
import FirebaseDatabase
import FirebaseAuth
import GoogleSignIn
import FirebaseStorage

class AppDelegate: NSObject, NSApplicationDelegate {
  var statusItem: NSStatusItem?
  
  func updateDeviceStatus(value: Int) {
    // 获取设备名称
    if let deviceName = Host.current().localizedName {
      print("Updating status for device: \(deviceName)")
      
      // 获取用户名
      if let uid = Auth.auth().currentUser?.uid {
        let ref = Database.database(url: "https://remotelocker-e2e68-default-rtdb.asia-southeast1.firebasedatabase.app").reference()
        ref.child(uid).child(deviceName).setValue(value) { (error, ref) in
          if let error = error {
            print("Failed to update status for device \(deviceName) under user \(uid): \(error.localizedDescription)")
          } else {
            print("Successfully updated status for device \(deviceName) under user \(uid) with value \(value)")
          }
        }
      } else {
        print("Failed to retrieve user name.")
      }
    } else {
      print("Failed to retrieve device name.")
    }
  }
  
  func obsFirebase() {
    // 初始化 Firebase 数据库的引用
    let ref = Database.database(url: "https://remotelocker-e2e68-default-rtdb.asia-southeast1.firebasedatabase.app").reference()
    
    // 获取设备名称
    if let deviceName = Host.current().localizedName {
      print("Device Name: \(deviceName)")
      
      // 获取用户名
      if let uid = Auth.auth().currentUser?.uid {
        // 监听该设备名称对应的键值
        ref.child(uid).child(deviceName).observe(.value) { [weak self] snapshot in
          guard let self = self else { return }
          
          // 检查值是否存在并且是整数类型
          if let value = snapshot.value as? Int {
            print("Value for \(deviceName) under user \(uid) updated: \(value)")
            
            // 值发生变化时执行动作
            self.performActionBasedOnValue(value)
          } else {
            print("No integer value found for \(deviceName) under user \(uid)")
          }
        }
      } else {
        print("Failed to retrieve user name.")
      }
    } else {
      print("Failed to retrieve device name.")
    }
  }
  
  // 根据获取到的值执行不同的动作
  func performActionBasedOnValue(_ value: Int) {
    print("Performing action for positive value: \(value)")
    
    if value == 0 {
      self.lockScreen()
    } else if value == 1 {
      
    }
  }
  
  func setupMenu() {
    // 创建菜单栏图标
    self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = self.statusItem?.button {
      button.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Lock Screen")
    }
    
    // 创建菜单项
    let menu = NSMenu()
    
    menu.addItem(NSMenuItem(title: "Lock Screen", action: #selector(self.setScreenShouldLock), keyEquivalent: "L"))
    
    if (GIDSignIn.sharedInstance.currentUser == nil) {
      menu.addItem(NSMenuItem(title: "Google Sign In", action: #selector(self.signInWithGoogle), keyEquivalent: "G"))
    } else {
      if let user = GIDSignIn.sharedInstance.currentUser {
        menu.addItem(NSMenuItem(title: "Current User: \(user.profile?.name ?? "Unknown")", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Current device: \(Host.current().localizedName ?? "Unknown")", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Sign Out", action: #selector(self.signOut), keyEquivalent: "O"))
      }
    }
    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: "Quit", action: #selector(self.quit), keyEquivalent: "Q"))
    
    self.statusItem?.menu = menu
  }
  
  @objc func signOut() {
    GIDSignIn.sharedInstance.signOut()
    self.setupMenu()
  }
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    FirebaseApp.configure()
    GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
      self.setupMenu()
      self.updateDeviceStatus(value: 1)
      if let currentUser = GIDSignIn.sharedInstance.currentUser {
        let credential = GoogleAuthProvider.credential(withIDToken: currentUser.idToken!.tokenString,
                                                       accessToken: currentUser.accessToken.tokenString)
        Auth.auth().signIn(with: credential) { authResult, error in
          if let error = error {
            print("Firebase sign in failed: \(error.localizedDescription)")
          } else {
            self.obsFirebase()
          }
        }
      }
    }
    
    // 不在 Dock 中显示图标
    NSApplication.shared.setActivationPolicy(.accessory)
    
    // 添加屏幕唤醒（解锁）的监听
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(screenDidWake),
      name: NSWorkspace.screensDidWakeNotification,
      object: nil
    )
  }
  
  @objc func screenDidWake(_ notification: Notification) {
    self.updateDeviceStatus(value: 1)
  }
  
  @objc func lockScreen() {
    let task = Process()
    task.launchPath = "/usr/bin/pmset"
    task.arguments = ["displaysleepnow"]
    task.launch()
  }
  
  @objc func setScreenShouldLock() {
    self.updateDeviceStatus(value: 0)
  }
  
  @objc func signInWithGoogle() {
    guard let presentingWindow = NSApplication.shared.windows.first else { return }
    
    // 使用 GIDSignIn.sharedInstance.signIn 方法进行 Google 登录
    GIDSignIn.sharedInstance.signIn(
      withPresenting: presentingWindow) { result, error in
        if let error = error {
          print("Error during Google Sign In: \(error.localizedDescription)")
          return
        }
        
        guard let user = result?.user, let idToken = user.idToken else { return }
        // 获取 Google OAuth 凭证
        let credential = GoogleAuthProvider.credential(
          withIDToken: idToken.tokenString,
          accessToken: user.accessToken.tokenString
        )
        
        // 使用 Firebase 进行身份认证
        Auth.auth().signIn(with: credential) { authResult, error in
          if let error = error {
            print("Firebase authentication failed: \(error.localizedDescription)")
          } else {
            print("Signed in successfully with Firebase using Google!")
            
            self.setupMenu()
            self.obsFirebase()
            self.updateDeviceStatus(value: 1)
          }
        }
      }
  }
  
  @objc func quit() {
    NSApplication.shared.terminate(self)
  }
}

//
//  PingClient.swift
//  ShadowsocksX-NG
//
//  Created by 杨晓民 on 2024/4/5.
//  Copyright © 2024 qiuyuzhou. All rights reserved.
//

import Foundation

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


public typealias SimplePingClientCallback = (String?)->()

open class SimplePingClient: NSObject {
    static let singletonPC = SimplePingClient()

    fileprivate var resultCallback: SimplePingClientCallback?
    fileprivate var pingClinet: SimplePing?
    fileprivate var dateReference: Date?
    fileprivate var timer: Timer?
    
    public static func pingHostname(_ hostname: String, andResultCallback callback: SimplePingClientCallback?) {
        singletonPC.pingHostname(hostname, andResultCallback: callback)
    }

    open func pingHostname(_ hostname: String, andResultCallback callback: SimplePingClientCallback?) {
        resultCallback = callback
        pingClinet = SimplePing(hostName: hostname)
        pingClinet?.delegate = self
        pingClinet?.start()
        
        // 设置超时计时器
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false, block: { [weak self] _ in
            self?.handleTimeout()
        })
    }
    
    open func handleTimeout() {
        // 处理超时逻辑
        pingClinet?.stop()
        
        // 调用超时的回调
        resultCallback?(nil)
        
        // 清除计时器引用
        timer?.invalidate()
        timer = nil
    }
}

extension SimplePingClient: SimplePingDelegate {
    public func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {
        pinger.send(with: nil)
    }

    @nonobjc public func simplePing(_ pinger: SimplePing, didFailWithError error: NSError) {
        resultCallback?(nil)
    }

    public func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
        dateReference = Date()
    }

    @nonobjc public func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: NSError) {
        pinger.stop()
        resultCallback?(nil)
    }

    public func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {
        pinger.stop()
        resultCallback?(nil)
    }

    public func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16 ){
        pinger.stop()

        guard let dateReference = dateReference else{return }

        //timeIntervalSinceDate returns seconds, so we convert to milis
        let latency = Date().timeIntervalSince(dateReference) * 1000
        resultCallback?(String(format: "%.f", latency))
    }
}

class PingServers:NSObject{
    static let instance = PingServers()

    let SerMgr = ServerProfileManager.instance
    var fastest:String?
    var fastest_id : Int=0

    func ping(_ i:Int=0){
        if i == 0{
            fastest_id = 0
            fastest = nil
        }

        if i >= SerMgr.profiles.count{
            DispatchQueue.main.async {
                // do the UI update HERE
                let message = "The fastest is \(self.SerMgr.profiles[self.fastest_id].remark) \(self.SerMgr.profiles[self.fastest_id].serverHost) \(self.SerMgr.profiles[self.fastest_id].latency!)ms";
                print(message)
                let alert = NSAlert.init()
                alert.alertStyle = .informational;
                alert.messageText = message.localized
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return
        }
        let host = self.SerMgr.profiles[i].serverHost
        SimplePingClient.pingHostname(host) { latency in
            DispatchQueue.global().async {
                print("[Ping Result]-\(host) latency is \(latency ?? "fail")")
                self.SerMgr.profiles[i].latency = latency ?? "fail"
                
                if latency != nil {
                    if self.fastest == nil{
                        self.fastest = latency
                        self.fastest_id = i
                    }else{
                        if Int(latency!) < Int(self.fastest!) {
                            self.fastest = latency
                            self.fastest_id = i
                        }
                    }
                    DispatchQueue.main.async {
                        // do the UI update HERE
                        (NSApplication.shared.delegate as! AppDelegate).updateServersMenu()
                        (NSApplication.shared.delegate as! AppDelegate).updateRunningModeMenu()
                    }
                }
            }
            self.ping(i+1)
        }
    }
}

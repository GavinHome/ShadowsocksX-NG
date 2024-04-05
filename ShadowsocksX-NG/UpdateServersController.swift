//
//  UpdateServersController.swift
//  ShadowsocksX-NG
//
//  Created by 杨晓民 on 2024/4/5.
//  Copyright © 2024 qiuyuzhou. All rights reserved.
//

import Foundation
import Cocoa

class UpdateServersController: NSWindowController {
    @IBOutlet weak var inputBox: NSTextField!
    
    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        
        var profiles: [String]? = getSubscribeUrls()
        if profiles != nil {
            inputBox.stringValue = profiles!.joined(separator: "\n");
        }
        
        let pb = NSPasteboard.general
        if #available(OSX 10.13, *) {
            if let text = pb.string(forType: NSPasteboard.PasteboardType.URL) {
                if let url = URL(string: text) {
                    if url.scheme == "http" || url.scheme == "https" {
                        inputBox.stringValue += "\n" + text
                    }
                }
            }
        }
        if let text = pb.string(forType: NSPasteboard.PasteboardType.string) {
            let urls = findHttpURLSInText(text)
            if urls.count > 0 {
                inputBox.stringValue += "\n" + text
            }
        }
        
    }
    
    @IBAction func handleUpdate(_ sender: NSButton) {
        sender.isEnabled = false;
        let urls = findHttpURLSInText(inputBox.stringValue)
        DispatchQueue.main.asyncAfter(
            deadline: DispatchTime.now() + DispatchTimeInterval.seconds(1),
            execute: {
                var subscribeURLs: [String] = [String]()
                var aggs: [String] = [String]();
                for url in urls {
                    subscribeURLs.append(url.absoluteString)
                    do {
                        var response: URLResponse?
                        var request = URLRequest(url: url)
                        request.httpMethod = "GET"
                        //request.setValue("*********", forHTTPHeaderField: "Authorization")
                        request.setValue("1", forHTTPHeaderField: "Version")
                        request.timeoutInterval = 12000
                        var received: Data? = try NSURLConnection.sendSynchronousRequest(request, returning: &response)
                        var result = String(data:received!, encoding: String.Encoding.utf8)
                        
                        if result != nil {
                            do {
                                let data = result!.data(using: String.Encoding.utf8)
                                let jsonArr = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as! [String]
                                aggs.append(result!)
                            } catch let err as NSError {
                                NSLog("JSONSerialization ERROR FROM \(url) \(result) \(err)")
                                if let base64String = result!.data(using: .utf8) {
                                    if let decodedData = Data(base64Encoded: base64String) {
                                        result = String(data: decodedData, encoding: .utf8)
                                        aggs.append(result!)
                                    }
                                }
                            }
                        }
                    } catch let error as NSError {
                        NSLog("FETCH SERVER ERROR FROM \(url) \(error)")
                    }
                }
                
                aggs.append( "ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTphNTAxYzgyYzcyZDc5MGI4@119.23.1.213:8474/?#%E5%B9%BF%E4%B8%9C%E7%9C%81%E6%B7%B1%E5%9C%B3%E5%B8%82+%E9%98%BF%E9%87%8C%E4%BA%91")
                let mgr = ServerProfileManager.instance
                let urls = ServerProfileManager.findURLSInText(aggs.joined(separator: "\r\n"))
                let addCount = mgr.addServerProfileByURL(urls: urls)
                self.saveSubscribeUrls(profiles: subscribeURLs)
                if addCount > 0 {
                    let alert = NSAlert.init()
                    alert.alertStyle = .informational;
                    alert.messageText = "Success to add \(addCount) server.".localized
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    sender.isEnabled = true;
                    self.close()
                } else {
                    let alert = NSAlert.init()
                    alert.alertStyle = .informational;
                    alert.messageText = "Not found valid shadowsocks server urls.".localized
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                    sender.isEnabled = true;
                }
            })
    }
    
    func findHttpURLSInText(_ text: String) -> [URL] {
        var urls = text.split(separator: "\n")
            .map { String($0).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .map { URL(string: $0) }
            .filter { $0 != nil }
            .map { $0! }
        urls = urls.filter { $0.scheme == "http" || $0.scheme == "https" }
        return urls
    }
    
    func getSubscribeUrls() -> [String]? {
        let defaults = UserDefaults.standard
        var profiles: [String]? = defaults.stringArray(forKey: "SubscribeUrlProfiles")
        return profiles
    }
    
    func saveSubscribeUrls(profiles: [String]) {
        let defaults = UserDefaults.standard
        defaults.set(profiles, forKey: "SubscribeUrlProfiles")
    }
}

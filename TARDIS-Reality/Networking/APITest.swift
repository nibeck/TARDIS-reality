//
//  APITest.swift
//  TARDIS-Reality
//
//  Created by Mike Nibeck on 12/29/25.
//

import Foundation
import TARDISAPIClient
import OpenAPIRuntime
import OpenAPIURLSession   // or AsyncHTTPClient if you chose that

let transport = URLSessionTransport()

let client = Client(
    serverURL: URL(string: "http://192.168.1.161")!,
    transport: transport
)

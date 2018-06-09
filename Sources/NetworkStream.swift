//
//  NetworkStream.swift
//  Starscream
//
//  Created by Damian Malarczyk on 09/06/2018.
//  Copyright © 2018 Vluxe. All rights reserved.
//

import Foundation
#if canImport(Network)
import Network

@available(macOS 10.14, *)
class NetworkStream: WSStream {

    private let connectionQueue = DispatchQueue(label: "network_stream_connection", attributes: [])

    enum Error: Swift.Error {

        case invalidPort
        case invalidHost
        case noConnection
    }

    weak var delegate: WSStreamDelegate?
    private var openConnection: NWConnection?
    let BUFFER_MAX = 4096

    func connect(url: URL, port: Int, timeout: TimeInterval, ssl: SSLSettings, completion: @escaping ((Swift.Error?) -> Void)) {
        guard let port = NWEndpoint.Port(rawValue: UInt16(port)) else {
            completion(Error.invalidPort)
            return
        }

        guard let rawHost = url.host else {
            completion(Error.invalidHost)
            return
        }

        let host = NWEndpoint.Host(rawHost)
        let tlsOptions: NWProtocolTLS.Options? = {
            guard ssl.useSSL else { return nil }

            return NWProtocolTLS.Options()
        }()

        let parameters = NWParameters.init(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        let connection = NWConnection(host: host, port: port, using: parameters)
        connection.start(queue: connectionQueue)

        connection.stateUpdateHandler = { [connection] state in
            switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    completion(nil)
                case .failed(let error):
                    connection.stateUpdateHandler = nil
                    completion(error)
                default: break
            }
        }
    }

    func write(data: inout Data, isCancelled: @escaping () -> Bool, completion: @escaping (Swift.Error?) -> Void) {
        guard let connection = openConnection else {
            completion(Error.noConnection)
            return
        }

        connection.send(content: data, completion: .contentProcessed { error in
            completion(error)
        })
    }

    func read(completion: @escaping (Data?) -> Void) {
        guard let connection = openConnection else {
            completion(nil)
            return
        }

        connection.receive(minimumIncompleteLength: 0, maximumLength: BUFFER_MAX) { data, contentContext, isComplete, error in
            completion(data)
        }
    }

    func cleanup() {
        openConnection?.stateUpdateHandler = nil
        openConnection?.cancel()
        openConnection = nil
    }

    func sslTrust() -> (trust: SecTrust?, domain: String?) {
        return (nil, nil)
    }
}


#endif

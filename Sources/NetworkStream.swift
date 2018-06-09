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

private let BUFFER_MAX = 4096

@available(macOS 10.14, *)
public class NetworkStream: WSStream {

    private let connectionQueue = DispatchQueue(label: "network_stream_connection", attributes: [])

    enum Error: Swift.Error {

        case invalidPort
        case invalidHost
        case noConnection
    }

    public weak var delegate: WSStreamDelegate?
    private var openConnection: NWConnection?

    private var readBuffer = Data(capacity: BUFFER_MAX * 2)
    public init() {}

    public func connect(url: URL, port: Int, timeout: TimeInterval, ssl: SSLSettings, completion: @escaping ((Swift.Error?) -> Void)) {
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

        connection.stateUpdateHandler = { [self, connection] state in
            switch state {
                case .ready:
                    self.openConnection = connection
                    connection.stateUpdateHandler = nil
                    completion(nil)
                    self.observeRead()
                case .failed(let error):
                    connection.stateUpdateHandler = nil
                    completion(error)
                default: break
            }
        }

        connection.start(queue: connectionQueue)
    }

    private func observeRead() {
        guard let connection = openConnection else { return }

        connection.receive(minimumIncompleteLength: 1, maximumLength: BUFFER_MAX) { [weak self] data, contentContext, isComplete, error in
            guard let `self` = self else { return }

            data.map { self.readBuffer.append(contentsOf: $0) }

            print("reading: \(data?.count ?? 0)")

            self.delegate?.newBytesInStream()
            if !isComplete {
                self.observeRead()
            }
        }
    }

    public func write(data: inout Data, isCancelled: @escaping () -> Bool, completion: @escaping (Swift.Error?) -> Void) {
        guard let connection = openConnection else {
            completion(Error.noConnection)
            return
        }

        connection.send(content: data, completion: .contentProcessed { error in
            completion(error)
        })
    }

    public func read() -> Data? {
        let data = readBuffer
        readBuffer.removeAll()
        return data.isEmpty ? nil : data
    }

    public func cleanup() {
        openConnection?.stateUpdateHandler = nil
        openConnection?.cancel()
        openConnection = nil
    }

    public func sslTrust() -> (trust: SecTrust?, domain: String?) {
        return (nil, nil)
    }
}


#endif

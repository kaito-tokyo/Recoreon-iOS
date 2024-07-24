// Derived from https://github.com/apple/swift-nio/blob/main/Sources/NIOHTTP1Server/main.swift

//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2017-2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import NIOCore
import NIOHTTP1
import NIOPosix

enum HLSServerError: Error {
  case localAddressPortNotAvailable
}

public struct HLSServer {
  public let port: Int

  private let channel: Channel

  public init(htdocs: String, host: String, port: Int = 0) throws {
    let fileIO = NonBlockingFileIO(threadPool: .singleton)

    func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
      channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
        channel.pipeline.addHandler(HTTPHandler(fileIO: fileIO, htdocsPath: htdocs))
      }
    }

    let socketBootstrap = ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
      // Specify backlog and enable SO_REUSEADDR for the server itself
      .serverChannelOption(ChannelOptions.backlog, value: 256)
      .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

      // Set the handlers that are applied to the accepted Channels
      .childChannelInitializer(childChannelInitializer(channel:))

      // Enable SO_REUSEADDR for the accepted Channels
      .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
      .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)

    channel = try socketBootstrap.bind(host: host, port: port).wait()

    guard let port = channel.localAddress?.port else {
      throw HLSServerError.localAddressPortNotAvailable
    }

    self.port = port
  }

  public func close() async throws {
    try await channel.eventLoop.shutdownGracefully()
  }

}

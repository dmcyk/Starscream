//
//  AsynchronousOperation.swift
//  Starscream
//
//  Created by Damian Malarczyk on 09/06/2018.
//  Copyright © 2018 Vluxe. All rights reserved.
//

import Foundation

class AsynchronousFinishOperation: Operation {

    private var _isExecuting: Bool = false {
        willSet {
            willChangeValue(for: \.isExecuting)
        }
        didSet {
            didChangeValue(for: \.isExecuting)
        }
    }

    private var _isFinished: Bool = false {
        willSet {
            willChangeValue(for: \.isFinished)
        }
        didSet {
            didChangeValue(for: \.isFinished)
        }
    }

    override var isExecuting: Bool {
        return _isExecuting
    }

    override var isFinished: Bool {
        return _isFinished
    }

    typealias MainCall = (@escaping () -> Bool, @escaping () -> Void) -> Void

    private var mainCall: MainCall

    init(_ call: @escaping MainCall) {
        self.mainCall = call
        super.init()
    }

    override func start() {
        guard !isFinished else { return }

        guard !isCancelled else {
            _isExecuting = false
            _isFinished = true
            return
        }

        _isExecuting = true
        main()
    }

    override func main() {
        mainCall({ [weak self] in
            return self?.isCancelled ?? true
        }, { [weak self] in
            guard self?.isCancelled == false else { return }

            self?._isExecuting = false
            self?._isFinished = true
        })
    }

    override func cancel() {
        _isExecuting = false
        _isFinished = true
    }
}

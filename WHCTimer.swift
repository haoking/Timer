//
//  WHCTimer.swift
//  MyFirstSwift
//
//  Created by Haochen Wang on 12/15/16.
//  Copyright © 2016 WHC. All rights reserved.
//

import Foundation

class WHCTimer: NSObject
{

    private var timeInterval : TimeInterval?
    private var timer : DispatchSource?
    private var target : AnyObject?
    private var selector : Selector?
    private var repeats : Bool = false
    private var serialQueue : DispatchQueue?

    private var _timerIsInvalidated : UInt32? = 0

    private init(timeInterval: TimeInterval, target: AnyObject?, selector: Selector, repeats: Bool)
    {
        super.init()
        self.timeInterval = timeInterval
        self.target = target
        self.selector = selector
        self.repeats = repeats
        let queueName = "WHCTimer.\(self)"
        self.serialQueue = DispatchQueue(label: queueName, qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: DispatchQueue.main)
        self.timer = DispatchSource.makeTimerSource(flags: [], queue: self.serialQueue) as? DispatchSource
        self.start()
    }

    public class func timerCreate(timeInterval: TimeInterval, target: AnyObject?, selector: Selector, repeats: Bool) -> WHCTimer
    {
        return WHCTimer.init(timeInterval: timeInterval, target: target, selector: selector, repeats: repeats)
    }

    private var _tolerance : TimeInterval? = 0
    private var tolerance: TimeInterval? {
        get
        {
            objc_sync_enter(self)
            return self._tolerance
        }

        set
        {
            objc_sync_enter(self)
            if newValue != _tolerance
            {
                self._tolerance = newValue
                self.resetTimerProperties()
            }
            objc_sync_exit(self)
        }
    }

    private func resetTimerProperties()
    {
        let intervalInNanoseconds : UInt64 = UInt64(self.timeInterval!) * NSEC_PER_SEC
        let toleranceInNanoseconds : UInt64 = UInt64(self.tolerance!) * NSEC_PER_SEC
        __dispatch_source_set_timer(self.timer!, DispatchTime.now().rawValue, intervalInNanoseconds, toleranceInNanoseconds)
    }

    public func start()
    {
        self.resetTimerProperties()

        __dispatch_source_set_event_handler(self.timer!, { [unowned self] in
            self.fire();
        })
        self.timer!.resume()
    }


    public func fire()
    {
        if (OSAtomicAnd32OrigBarrier(1, &_timerIsInvalidated!) > 0)
        {
            return;
        }

        _ = self.target!.perform(self.selector, with: self)

        if self.repeats == false
        {
            self.cancel();
        }
    }

    public func cancel()
    {
        if (!OSAtomicTestAndSetBarrier(7, &_timerIsInvalidated))
        {
            let timer : DispatchSource = self.timer!
            self.serialQueue!.async {
                timer.cancel()
            }
        }
    }

    deinit
    {
        self.cancel()
    }

}

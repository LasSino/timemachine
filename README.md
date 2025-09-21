# timemachine
A ruby gem providing timeout and timeup executors.

The gem provides the function to run a task after a specified timeout / timeup, similar to `SetTimeout` in Javascript.

**Note:**
In programs where `Fiber` and `FiberScheduler` are used, simple `Kernel#sleep` is usually perfect choice to use. 
However, this gem aims to meet the need where traditional synchronous and thread-based programming are still in use.

## Usage

### Schedule a task

To schedule a task is simple using `TimeMachine#after` and `TimeMachine#at`:

```Ruby
require 'timemachine'

tm = TimeMachine::TimeMachine.new
tm.start # This creates a background thread to schedule the tasks.

tm.after(1.5) { puts "Hello, world" }
# This is approximately equivalent to:
# `tm.at(Time.now + 1.5) { puts "Hello, world" }`

# (approximately yet closely) 1.5 second after
# > Hello, world
```

It is also possible to cancel a task:

```Ruby
# ... same preparations as above
counter = 0

handle1 = tm.after(1.5) { counter += 1 }
handle2 = tm.after(1.5) { counter += 2 }

sleep(1)

tm.cancel(handle1)

sleep(1)

p counter
# the first task will not be executed, while the second executes as expected:
# > 2
```
*Note:* If you want to cancel a task, cancel it in time. Or the task may be already executed.

### Collect the result

You can also collect the result:

```Ruby
# ... same preparations as above

handle = tm.after(1.5, record_result: true) do
  "Doing some really hard computation!"  
  1+1 
end

p tm.get_result(handle)
# Still executing:
# > #<struct TimeMachine::TaskResult handle="mftvinv9vhi2ramo", status=:PENDING, record_result=true, result=nil

sleep(1.5)

p tm.get_result(handle)
# > #<struct TimeMachine::TaskResult handle="mftvinv9vhi2ramo", status=:FINISHED, record_result=true, result=2>
p tm.get_result(handle).result
# > 2

# Remember to use `TimeMachine#pop_result` to remove the result, or it will take up the memory all the time!
p tm.pop_result(handle).result
# > 2
```

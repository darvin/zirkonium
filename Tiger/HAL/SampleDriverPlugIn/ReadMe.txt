This project illustrates implementing a plug-in to the Core Audio HAL that conforms to the API in <CoreAudio/AudioDriverPlugIn.h>.

The purpose of this kind of plug-in is to give IOAudio-based drivers a way to provide custom properties for their devices through the HAL's API. This API allows for the plug-in to override standard properties that do not affect I/O.

The plug-in the project implements the following:
- all the bundle entry points via the base class HP_DriverPlugIn.h
- a single device wide property called Foo whose value is a UInt32
- opening a connection to the IOAudioEngine in the driver and setting up a mach port to receive notifications from the engine

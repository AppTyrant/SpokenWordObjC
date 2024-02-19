# Recognizing speech in live audio

Perform speech recognition on audio coming from the microphone of an iOS device. This is an Objective-C port of Apple's Swift sample code.

## Overview

This sample project demonstrates how to use the Speech framework to recognize words from captured audio. When the user taps the Start Recording button, the SpokenWord app begins capturing audio from the device’s microphone. It routes that audio to the APIs of the Speech framework, which process the audio and send back any recognized text. The app displays the recognized text in its text view, continuously updating that text until you tap the Stop Recording button. The sample app doesn't run in Simulator, so you need to run it on a physical device with iOS 17 or later, or iPadOS 17 or later.

![On the left, the app lets the user know that it is ready to begin speech recognition. On the right, the app uses speech recognition to display what the user said.](Documentation/sample-screens_2x.png) 


- Important: Apps need to include the `NSSpeechRecognitionUsageDescription` key in their `Info.plist` file and request authorization to perform speech recognition. For information about requesting authorization, see [Asking Permission to Use Speech Recognition](https://developer.apple.com/documentation/speech/asking_permission_to_use_speech_recognition). 

## Configure the microphone using AVFoundation

The SpokenWordObjC app uses AVFoundation to communicate with the device’s microphone. Specifically, the app configures the shared [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession) object to manage the app’s audio interactions with the rest of the system, and it configures an [AVAudioEngine](https://developer.apple.com/documentation/avfaudio/avaudioengine) object to retrieve the microphone input.

Tapping the app's Start Recording button retrieves the shared [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession) object, configures it for recording, and makes it the active session. Activating the session lets the system know that the app needs the microphone resource. If that resource is unavailable — perhaps because the user is talking on the phone — the [setActive(_:options:)](https://developer.apple.com/documentation/avfaudio/avaudiosession/1616627-setactive) method throws an exception. 

When the session is active, the app retrieves the [AVAudioInputNode](https://developer.apple.com/documentation/avfaudio/avaudioinputnode) object from its audio engine and stores it in the local `inputNode` variable. The input node represents the current audio input path, which can be the device’s built-in microphone or a microphone connected to a set of headphones. 

To begin recording, the app installs a tap on the input node and starts up the audio engine, which begins collecting samples into an internal buffer. When a buffer is full, the audio engine calls the provided block. The app’s implementation of that block passes the samples directly to the request object's [-appendAudioPCMBuffer:](https://developer.apple.com/documentation/speech/sfspeechaudiobufferrecognitionrequest/1649389-appendaudiopcmbuffer?language=objc) method, which accumulates the audio samples and delivers them to the speech recognition system. 

## Create the speech recognition request

To recognize speech from live audio, SpokenWord creates and configures an [SFSpeechAudioBufferRecognitionRequest](https://developer.apple.com/documentation/speech/sfspeechaudiobufferrecognitionrequest) object. When it receives recognition results, the app updates its text view accordingly. The app sets the request object's [shouldReportPartialResults](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/1649392-shouldreportpartialresults) property to `true`, which causes the speech recognition system to return intermediate results as they are recognized. 

#### Developer's Website:
[AppTyrant.com](https://AppTyrant.com)

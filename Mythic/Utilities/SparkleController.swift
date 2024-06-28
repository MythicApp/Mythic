import Sparkle

final class SparkleController: ObservableObject {
    init(delegate: SPUUpdaterDelegate? = nil) {
        self.updaterController = .init(
            startingUpdater: true,
            updaterDelegate: delegate,
            userDriverDelegate: nil
        )
    }
    
    var updaterController: SPUStandardUpdaterController

    var updater: SPUUpdater {
        updaterController.updater
    }
}

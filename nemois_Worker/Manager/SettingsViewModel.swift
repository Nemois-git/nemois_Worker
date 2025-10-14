

//
//  SettingsViewModel.swift
//  nemois_Worker
//
//  Created by nemois on 10/14/25.
//

import Foundation
import Combine

/// `SettingsView`를 위한 데이터와 로직을 관리하는 `ObservableObject`입니다.
/// 이 ViewModel은 앱의 설정을 관리하며, 특히 모델 저장 경로와 같은
/// 사용자가 지정하는 옵션을 `UserDefaults`에 영속적으로 저장하고 불러오는 역할을 합니다.
class SettingsViewModel: ObservableObject {
    
    /// 사용자가 선택한 모델의 유형을 나타냅니다. (예: 내장 모델, 커스텀 모델)
    @Published var modelSelection: ModelSelectionOption {
        didSet {
            UserDefaults.standard.set(modelSelection.rawValue, forKey: Keys.modelSelection)
        }
    }
    
    @Published var serverPort: Int {
        didSet {
            UserDefaults.standard.set(serverPort, forKey: Keys.serverPort)
        }
    }
    
    private enum Keys {
        static let modelSelection = "modelSelection"
        static let modelStoragePath = "modelStoragePath"
        static let serverPort = "serverPort"
    }
    
    init() {
        // UserDefaults에서 저장된 설정을 불러옵니다.
        let selectionRawValue = UserDefaults.standard.string(forKey: Keys.modelSelection) ?? ModelSelectionOption.builtIn.rawValue
        self.modelSelection = ModelSelectionOption(rawValue: selectionRawValue) ?? .builtIn
        let savedPort = UserDefaults.standard.integer(forKey: Keys.serverPort)
        self.serverPort = (savedPort > 0) ? savedPort : 8080
    }
}

/// 사용자가 선택할 수 있는 모델의 종류를 정의하는 열거형입니다.
enum ModelSelectionOption: String, CaseIterable, Identifiable {
    case builtIn = "Built-in Foundation Model"
    
    var id: String { self.rawValue }
}

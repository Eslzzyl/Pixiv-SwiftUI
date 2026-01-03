import SwiftUI
import TranslationKit

extension View {
    @ViewBuilder
    func autocapitalizationDisabled() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func urlKeyboardType() -> some View {
        #if os(iOS)
        self.keyboardType(.URL)
        #else
        self
        #endif
    }
}

struct TranslationSettingView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    
    @State private var primaryServiceId: String = ""
    @State private var backupServiceId: String = ""
    @State private var targetLanguage: String = ""
    @State private var openAIApiKey: String = ""
    @State private var openAIBaseURL: String = ""
    @State private var openAIModel: String = ""
    @State private var openAITemperature: Double = 0.3
    @State private var baiduAppid: String = ""
    @State private var baiduKey: String = ""
    @State private var googleApiKey: String = ""
    
    @State private var isTestingOpenAI: Bool = false
    @State private var isTestingBaidu: Bool = false
    @State private var isTestingGoogleAPI: Bool = false
    @State private var toastMessage: String = ""
    @State private var showToast: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                servicePrioritySection
                languageSection
                serviceConfigSection
            }
            .navigationTitle("翻译设置")
            .onAppear {
                loadSettings()
            }
            .onDisappear {
                saveSettings()
            }
            .toast(isPresented: $showToast, message: toastMessage)
        }
    }
    
    private var servicePrioritySection: some View {
        Section {
            Picker("首选服务", selection: $primaryServiceId) {
                ForEach(userSettingStore.availableTranslateServices, id: \.id) { service in
                    Text(service.name).tag(service.id)
                }
            }
            
            Picker("备选服务", selection: $backupServiceId) {
                ForEach(userSettingStore.availableTranslateServices, id: \.id) { service in
                    Text(service.name).tag(service.id)
                }
            }
        } header: {
            Text("服务优先级")
        } footer: {
            Text("当首选服务不可用时，将自动使用备选服务进行翻译。")
        }
    }
    
    private var languageSection: some View {
        Section {
            Picker("目标语言", selection: $targetLanguage) {
                ForEach(userSettingStore.availableLanguages, id: \.code) { language in
                    Text(language.name).tag(language.code)
                }
            }
        } header: {
            Text("翻译语言")
        } footer: {
            Text("翻译时默认将内容翻译为目标语言。")
        }
    }
    
    @ViewBuilder
    private var serviceConfigSection: some View {
        if primaryServiceId == "openai" || backupServiceId == "openai" {
            openAIServiceConfig
        }
        if primaryServiceId == "baidu" || backupServiceId == "baidu" {
            baiduServiceConfig
        }
        if primaryServiceId == "googleapi" || backupServiceId == "googleapi" {
            googleApiServiceConfig
        }
    }
    
    private var openAIServiceConfig: some View {
        Section {
            SecureField("API Key", text: $openAIApiKey)
                .textContentType(.password)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()
            
            TextField("Base URL", text: $openAIBaseURL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()
                .urlKeyboardType()
            
            TextField("模型", text: $openAIModel)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("温度: \(openAITemperature, specifier: "%.1f")")
                Slider(value: $openAITemperature, in: 0...2, step: 0.1)
            }
            
            Button {
                testOpenAIService()
            } label: {
                ZStack {
                    if isTestingOpenAI {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("测试服务")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: .blue))
            .disabled(isTestingOpenAI || openAIApiKey.isEmpty)
        } header: {
            Text("OpenAI 配置")
        } footer: {
            Text("配置 OpenAI 或兼容的 LLM 服务。API Key 为必填项，不配置将无法使用此服务。")
        }
    }
    
    private var baiduServiceConfig: some View {
        Section {
            TextField("AppID", text: $baiduAppid)
                .textContentType(.none)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()
            
            SecureField("API Key", text: $baiduKey)
                .textContentType(.password)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()
            
            Button {
                testBaiduService()
            } label: {
                ZStack {
                    if isTestingBaidu {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("测试服务")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: .blue))
            .disabled(isTestingBaidu || baiduAppid.isEmpty || baiduKey.isEmpty)
        } header: {
            Text("百度翻译配置")
        } footer: {
            Text("请在百度翻译开放平台申请 AppID 和 API Key。")
        }
    }
    
    private var googleApiServiceConfig: some View {
        Section {
            SecureField("API Key", text: $googleApiKey)
                .textContentType(.password)
                .autocorrectionDisabled()
                .autocapitalizationDisabled()
            
            Button {
                testGoogleAPIService()
            } label: {
                ZStack {
                    if isTestingGoogleAPI {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("测试服务")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: .blue))
            .disabled(isTestingGoogleAPI || googleApiKey.isEmpty)
        } header: {
            Text("Google Translate API 配置")
        } footer: {
            Text("Google Translate API 需要 API Key，请在 Google Cloud Platform 申请。")
        }
    }
    
    private func loadSettings() {
        primaryServiceId = userSettingStore.userSetting.translatePrimaryServiceId
        backupServiceId = userSettingStore.userSetting.translateBackupServiceId
        targetLanguage = userSettingStore.userSetting.translateTargetLanguage
        openAIApiKey = userSettingStore.userSetting.translateOpenAIApiKey
        openAIBaseURL = userSettingStore.userSetting.translateOpenAIBaseURL
        openAIModel = userSettingStore.userSetting.translateOpenAIModel
        openAITemperature = userSettingStore.userSetting.translateOpenAITemperature
        baiduAppid = userSettingStore.userSetting.translateBaiduAppid
        baiduKey = userSettingStore.userSetting.translateBaiduKey
        googleApiKey = userSettingStore.userSetting.translateGoogleApiKey
    }
    
    private func saveSettings() {
        try? userSettingStore.setTranslatePrimaryServiceId(primaryServiceId)
        try? userSettingStore.setTranslateBackupServiceId(backupServiceId)
        try? userSettingStore.setTranslateTargetLanguage(targetLanguage)
        try? userSettingStore.setTranslateOpenAIApiKey(openAIApiKey)
        try? userSettingStore.setTranslateOpenAIBaseURL(openAIBaseURL)
        try? userSettingStore.setTranslateOpenAIModel(openAIModel)
        try? userSettingStore.setTranslateOpenAITemperature(openAITemperature)
        try? userSettingStore.setTranslateBaiduAppid(baiduAppid)
        try? userSettingStore.setTranslateBaiduKey(baiduKey)
        try? userSettingStore.setTranslateGoogleApiKey(googleApiKey)
    }
    
    private func createOpenAIService() -> OpenAITranslateService {
        OpenAITranslateService(
            baseURL: openAIBaseURL.isEmpty ? "https://api.openai.com/v1" : openAIBaseURL,
            apiKey: openAIApiKey,
            model: openAIModel.isEmpty ? "gpt-3.5-turbo" : openAIModel,
            temperature: openAITemperature
        )
    }
    
    private func createBaiduService() -> BaiduTranslateService {
        let config = BaiduTranslateConfig(
            appid: baiduAppid,
            key: baiduKey,
            action: "0"
        )
        return BaiduTranslateService(config: config)
    }
    
    private func createGoogleAPIService() -> GoogleAPITranslateService {
        GoogleAPITranslateService()
    }
    
    private func testOpenAIService() {
        guard !isTestingOpenAI else { return }
        isTestingOpenAI = true
        
        Task {
            do {
                let service = createOpenAIService()
                var task = TranslateTask(
                    raw: "Hello World",
                    sourceLanguage: "en",
                    targetLanguage: targetLanguage.isEmpty ? "zh-CN" : targetLanguage
                )
                try await service.translate(&task)
                
                await MainActor.run {
                    isTestingOpenAI = false
                    if !task.result.isEmpty {
                        toastMessage = "测试成功"
                    } else {
                        toastMessage = "测试成功，但未返回翻译结果"
                    }
                    showToast = true
                }
            } catch {
                await MainActor.run {
                    isTestingOpenAI = false
                    toastMessage = "测试失败: \(error.localizedDescription)"
                    showToast = true
                }
            }
        }
    }
    
    private func testBaiduService() {
        guard !isTestingBaidu else { return }
        isTestingBaidu = true
        
        Task {
            do {
                let service = createBaiduService()
                var task = TranslateTask(
                    raw: "Hello World",
                    sourceLanguage: "en",
                    targetLanguage: targetLanguage.isEmpty ? "zh-CN" : targetLanguage
                )
                try await service.translate(&task)
                
                await MainActor.run {
                    isTestingBaidu = false
                    if !task.result.isEmpty {
                        toastMessage = "测试成功"
                    } else {
                        toastMessage = "测试成功，但未返回翻译结果"
                    }
                    showToast = true
                }
            } catch {
                await MainActor.run {
                    isTestingBaidu = false
                    toastMessage = "测试失败: \(error.localizedDescription)"
                    showToast = true
                }
            }
        }
    }
    
    private func testGoogleAPIService() {
        guard !isTestingGoogleAPI else { return }
        isTestingGoogleAPI = true
        
        Task {
            do {
                let service = createGoogleAPIService()
                var task = TranslateTask(
                    raw: "Hello World",
                    sourceLanguage: "en",
                    targetLanguage: targetLanguage.isEmpty ? "zh-CN" : targetLanguage
                )
                try await service.translate(&task)
                
                await MainActor.run {
                    isTestingGoogleAPI = false
                    if !task.result.isEmpty {
                        toastMessage = "测试成功"
                    } else {
                        toastMessage = "测试成功，但未返回翻译结果"
                    }
                    showToast = true
                }
            } catch {
                await MainActor.run {
                    isTestingGoogleAPI = false
                    toastMessage = "测试失败: \(error.localizedDescription)"
                    showToast = true
                }
            }
        }
    }
}

#Preview {
    TranslationSettingView()
}

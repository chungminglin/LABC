package android_neverstand.service

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

object BeaconManagerState {
    private val _isScanning = MutableStateFlow(false)
    val isScanning: StateFlow<Boolean> = _isScanning.asStateFlow()
    
    private val _statusMessage = MutableStateFlow("Ready to scan")
    val statusMessage: StateFlow<String> = _statusMessage.asStateFlow()
    
    private val _suggestions = MutableStateFlow<List<String>>(emptyList())
    val suggestions: StateFlow<List<String>> = _suggestions.asStateFlow()
    
    fun setScanning(scanning: Boolean) {
        _isScanning.value = scanning
    }
    
    fun setStatusMessage(message: String) {
        _statusMessage.value = message
    }
    
    fun setSuggestions(suggs: List<String>) {
        _suggestions.value = suggs
    }
}

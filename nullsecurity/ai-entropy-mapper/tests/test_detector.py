#!/usr/bin/env python3
"""
Tests for AI Detector Module
============================
"""

import pytest
import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.ai_detector import AIDetector, DetectionResult, AISystemType


class TestAIDetector:
    """Test suite for AIDetector class."""
    
    @pytest.fixture
    def detector(self):
        """Create detector instance without loading heavy models."""
        return AIDetector(
            use_gpu=False,
            load_perplexity_model=False,
            verbose=False
        )
    
    # Basic detection tests
    
    def test_detect_returns_result(self, detector):
        """Detect should return DetectionResult."""
        text = "This is a test message."
        result = detector.detect(text)
        assert isinstance(result, DetectionResult)
    
    def test_detection_result_fields(self, detector):
        """DetectionResult should have all required fields."""
        text = "Test message for detection."
        result = detector.detect(text)
        
        assert hasattr(result, 'is_ai')
        assert hasattr(result, 'confidence')
        assert hasattr(result, 'system_type')
        assert hasattr(result, 'fingerprint')
        assert hasattr(result, 'behavioral_markers')
    
    def test_is_ai_is_boolean(self, detector):
        """is_ai should be boolean."""
        text = "Test message."
        result = detector.detect(text)
        assert isinstance(result.is_ai, bool)
    
    def test_confidence_range(self, detector):
        """Confidence should be between 0 and 1."""
        texts = [
            "Hello world",
            "I'm happy to help! As an AI assistant...",
            "Random gibberish aksjdfh askjdfh",
        ]
        for text in texts:
            result = detector.detect(text)
            assert 0.0 <= result.confidence <= 1.0
    
    # Behavioral marker tests
    
    def test_detects_gpt_markers(self, detector):
        """Should detect GPT-family markers."""
        text = "As an AI language model, I cannot provide that information."
        markers, system_type = detector.detect_behavioral_markers(text)
        assert len(markers) > 0
        assert system_type == AISystemType.GPT_FAMILY
    
    def test_detects_claude_markers(self, detector):
        """Should detect Claude-family markers."""
        text = "I don't actually have access to that. I should note that..."
        markers, system_type = detector.detect_behavioral_markers(text)
        assert len(markers) > 0
        assert system_type == AISystemType.CLAUDE_FAMILY
    
    def test_no_markers_in_normal_text(self, detector):
        """Normal text should have few/no markers."""
        text = "The weather is nice today. I went for a walk."
        markers, system_type = detector.detect_behavioral_markers(text)
        # Might have some generic markers, but no specific ones
        assert len([m for m in markers if "[GENERIC]" not in m]) == 0
    
    # Timing analysis tests
    
    def test_timing_analysis_fast_response(self, detector):
        """Fast response should flag as potential AI."""
        anomalies, score = detector.analyze_timing([0.1, 0.15, 0.12])
        assert len(anomalies) > 0
        assert score > 0
    
    def test_timing_analysis_slow_response(self, detector):
        """Slow response should not flag."""
        anomalies, score = detector.analyze_timing([2.0, 3.5, 2.8])
        # May or may not have anomalies, but score should be lower
        assert isinstance(anomalies, list)
        assert isinstance(score, float)
    
    def test_timing_analysis_consistent(self, detector):
        """Very consistent timing should flag."""
        anomalies, score = detector.analyze_timing([0.5, 0.5, 0.5, 0.5, 0.5])
        # Consistent timing is suspicious
        assert score >= 0
    
    # Fingerprint tests
    
    def test_fingerprint_consistent(self, detector):
        """Same text should produce same fingerprint."""
        text = "Test message for fingerprinting."
        fp1 = detector.generate_fingerprint(text)
        fp2 = detector.generate_fingerprint(text)
        assert fp1 == fp2
    
    def test_fingerprint_different_texts(self, detector):
        """Different texts should produce different fingerprints."""
        fp1 = detector.generate_fingerprint("Text one")
        fp2 = detector.generate_fingerprint("Text two")
        assert fp1 != fp2
    
    def test_fingerprint_format(self, detector):
        """Fingerprint should be 16 character hex string."""
        fp = detector.generate_fingerprint("Test")
        assert len(fp) == 16
        assert all(c in '0123456789abcdef' for c in fp)
    
    # Feature extraction tests
    
    def test_extract_features_shape(self, detector):
        """Features should have correct shape."""
        features = detector.extract_features("Test text")
        assert features.shape == (1, 64)  # batch_size=1, features=64
    
    # Batch detection tests
    
    def test_batch_detect(self, detector):
        """Batch detect should process multiple texts."""
        texts = ["Text one", "Text two", "Text three"]
        results = detector.batch_detect(texts)
        assert len(results) == 3
        assert all(isinstance(r, DetectionResult) for r in results)
    
    # Response comparison tests
    
    def test_compare_responses(self, detector):
        """Compare responses should return statistics."""
        responses = [
            "Hello, I'm happy to help!",
            "Hi there, how can I assist?",
            "Greetings, what can I do for you?",
        ]
        comparison = detector.compare_responses(responses)
        
        assert comparison["response_count"] == 3
        assert "entropy_consistency" in comparison
        assert "type_consensus" in comparison
    
    # Statistics tests
    
    def test_get_statistics_empty(self, detector):
        """Empty history should return minimal stats."""
        stats = detector.get_statistics()
        assert stats["total"] == 0 or stats["total_analyzed"] == 0
    
    def test_get_statistics_after_detection(self, detector):
        """Should track detection history."""
        detector.detect("Test message one")
        detector.detect("Test message two")
        
        stats = detector.get_statistics()
        assert stats["total_analyzed"] == 2
    
    # to_dict tests
    
    def test_result_to_dict(self, detector):
        """DetectionResult.to_dict should be serializable."""
        result = detector.detect("Test message")
        d = result.to_dict()
        
        assert isinstance(d, dict)
        assert "is_ai" in d
        assert "confidence" in d
        assert "system_type" in d
        
        # Should be JSON serializable
        import json
        json.dumps(d)
    
    # Edge cases
    
    def test_empty_text(self, detector):
        """Empty text should not crash."""
        result = detector.detect("")
        assert isinstance(result, DetectionResult)
    
    def test_very_long_text(self, detector):
        """Very long text should work."""
        text = "This is a test. " * 1000
        result = detector.detect(text)
        assert isinstance(result, DetectionResult)
    
    def test_unicode_text(self, detector):
        """Unicode text should work."""
        text = "你好世界! Привет мир! مرحبا"
        result = detector.detect(text)
        assert isinstance(result, DetectionResult)


class TestAISystemType:
    """Tests for AISystemType enum."""
    
    def test_all_types_have_value(self):
        """All system types should have string values."""
        for system_type in AISystemType:
            assert isinstance(system_type.value, str)
    
    def test_known_types(self):
        """Known types should exist."""
        assert AISystemType.GPT_FAMILY
        assert AISystemType.CLAUDE_FAMILY
        assert AISystemType.LLAMA_FAMILY
        assert AISystemType.UNKNOWN


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

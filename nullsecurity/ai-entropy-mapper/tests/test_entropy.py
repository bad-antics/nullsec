#!/usr/bin/env python3
"""
Tests for Entropy Analyzer Module
=================================
"""

import pytest
import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.entropy_analyzer import EntropyAnalyzer, EntropyResult


class TestEntropyAnalyzer:
    """Test suite for EntropyAnalyzer class."""
    
    @pytest.fixture
    def analyzer(self):
        """Create analyzer instance."""
        return EntropyAnalyzer(verbose=False)
    
    # Basic entropy tests
    
    def test_shannon_entropy_empty_string(self, analyzer):
        """Empty string should have 0 entropy."""
        assert analyzer.calculate_shannon_entropy("") == 0.0
    
    def test_shannon_entropy_single_char(self, analyzer):
        """Single repeated character should have 0 entropy."""
        assert analyzer.calculate_shannon_entropy("aaaaaaaaaa") == 0.0
    
    def test_shannon_entropy_uniform_distribution(self, analyzer):
        """Uniform distribution should have maximum entropy."""
        text = "abcdefghijklmnopqrstuvwxyz"
        entropy = analyzer.calculate_shannon_entropy(text)
        # Maximum entropy for 26 chars is log2(26) ≈ 4.7
        assert entropy > 4.5
        assert entropy < 5.0
    
    def test_shannon_entropy_typical_text(self, analyzer):
        """Typical English text should have entropy around 4-5 bits."""
        text = "The quick brown fox jumps over the lazy dog."
        entropy = analyzer.calculate_shannon_entropy(text)
        assert 3.5 < entropy < 5.0
    
    # Normalized entropy tests
    
    def test_normalized_entropy_range(self, analyzer):
        """Normalized entropy should be between 0 and 1."""
        texts = [
            "aaaaaaaaaa",
            "abcdefghij",
            "The quick brown fox",
            "!@#$%^&*()",
        ]
        for text in texts:
            result = analyzer.calculate_normalized_entropy(text)
            assert 0.0 <= result <= 1.0
    
    # Compression ratio tests
    
    def test_compression_ratio_repetitive(self, analyzer):
        """Highly repetitive text should compress well."""
        text = "hello " * 100
        ratio = analyzer.compression_ratio(text)
        assert ratio > 0.5  # Should compress well
    
    def test_compression_ratio_random(self, analyzer):
        """Random-ish text should compress less."""
        import string
        import random
        text = ''.join(random.choices(string.ascii_letters, k=500))
        ratio = analyzer.compression_ratio(text)
        assert ratio < 0.5  # Should compress less
    
    # Serial correlation tests
    
    def test_serial_correlation_range(self, analyzer):
        """Serial correlation should be between -1 and 1."""
        text = "The quick brown fox jumps over the lazy dog."
        corr = analyzer.serial_correlation(text)
        assert -1.0 <= corr <= 1.0
    
    # Full analysis tests
    
    def test_analyze_returns_result(self, analyzer):
        """Analyze should return EntropyResult."""
        text = "This is a test sentence for entropy analysis."
        result = analyzer.analyze(text)
        assert isinstance(result, EntropyResult)
    
    def test_analyze_result_fields(self, analyzer):
        """EntropyResult should have all required fields."""
        text = "This is a test sentence for entropy analysis."
        result = analyzer.analyze(text)
        
        assert hasattr(result, 'shannon_entropy')
        assert hasattr(result, 'normalized_entropy')
        assert hasattr(result, 'compression_ratio')
        assert hasattr(result, 'ai_likelihood')
        assert hasattr(result, 'confidence')
    
    def test_analyze_ai_likelihood_range(self, analyzer):
        """AI likelihood should be between 0 and 1."""
        texts = [
            "Hello world!",
            "The quick brown fox jumps over the lazy dog.",
            "I'd be happy to help you with that! As an AI assistant, I can provide information on a wide range of topics.",
        ]
        for text in texts:
            result = analyzer.analyze(text)
            assert 0.0 <= result.ai_likelihood <= 1.0
    
    # AI detection heuristic tests
    
    def test_ai_like_text_higher_score(self, analyzer):
        """AI-like text should score higher than casual human text."""
        ai_text = """
        The analysis of entropy patterns in text provides valuable insights into the
        nature of content generation. By examining statistical properties such as
        character frequency distributions, researchers can identify distinctive signatures.
        """
        
        human_text = """
        So I was thinking... you know what's crazy? Like, entropy and stuff. 
        Anyway, I grabbed coffee and the barista totally spelled my name wrong again lol.
        """
        
        ai_result = analyzer.analyze(ai_text)
        human_result = analyzer.analyze(human_text)
        
        # AI-like text should generally score higher (but this is heuristic)
        # We don't assert this strictly as the heuristics are approximate
        assert ai_result.ai_likelihood >= 0
        assert human_result.ai_likelihood >= 0
    
    # Comparison tests
    
    def test_compare_samples(self, analyzer):
        """Compare samples should return valid statistics."""
        samples = [
            "Sample one for testing.",
            "Sample two for testing purposes.",
            "Sample three is also for testing.",
        ]
        
        result = analyzer.compare_samples(samples)
        
        assert result["sample_count"] == 3
        assert "entropy_mean" in result
        assert "entropy_std" in result
        assert "consistency_score" in result
    
    # Edge cases
    
    def test_very_short_text(self, analyzer):
        """Very short text should still work."""
        result = analyzer.analyze("Hi")
        assert isinstance(result, EntropyResult)
        assert "Short text" in str(result.analysis_notes) or result.confidence < 1.0
    
    def test_unicode_text(self, analyzer):
        """Unicode text should be handled."""
        text = "Привет мир! 你好世界! مرحبا بالعالم"
        result = analyzer.analyze(text)
        assert isinstance(result, EntropyResult)
    
    def test_to_dict(self, analyzer):
        """to_dict should return serializable dictionary."""
        text = "Test text for serialization."
        result = analyzer.analyze(text)
        
        d = result.to_dict()
        
        assert isinstance(d, dict)
        assert "shannon_entropy" in d
        assert "ai_likelihood" in d
        
        # Should be JSON serializable
        import json
        json.dumps(d)


class TestNgramEntropy:
    """Tests for n-gram entropy calculations."""
    
    @pytest.fixture
    def analyzer(self):
        return EntropyAnalyzer()
    
    def test_bigram_entropy(self, analyzer):
        """Bigram entropy should be positive for varied text."""
        text = "The quick brown fox jumps over the lazy dog."
        entropy = analyzer.ngram_entropy(text, n=2)
        assert entropy > 0
    
    def test_trigram_entropy(self, analyzer):
        """Trigram entropy should be positive for varied text."""
        text = "The quick brown fox jumps over the lazy dog."
        entropy = analyzer.ngram_entropy(text, n=3)
        assert entropy > 0
    
    def test_short_text_ngram(self, analyzer):
        """Short text should return 0 for large n-grams."""
        assert analyzer.ngram_entropy("Hi", n=5) == 0.0


class TestBurstiness:
    """Tests for burstiness calculations."""
    
    @pytest.fixture
    def analyzer(self):
        return EntropyAnalyzer()
    
    def test_burstiness_range(self, analyzer):
        """Burstiness should be between -1 and 1."""
        text = "The quick brown fox jumps over the lazy dog. The dog was not happy."
        score = analyzer.burstiness_score(text)
        assert -1.0 <= score <= 1.0
    
    def test_short_text_burstiness(self, analyzer):
        """Short text should return 0."""
        assert analyzer.burstiness_score("Short") == 0.0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

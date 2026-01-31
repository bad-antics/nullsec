#!/usr/bin/env python3
"""
Entropy Analysis Module
=======================

Measures randomness and statistical properties in text/responses to identify
AI-generated content patterns.

Techniques:
- Shannon Entropy calculation
- Chi-squared randomness test
- Serial correlation analysis
- N-gram frequency analysis
- Compression ratio testing
"""

import math
import zlib
import string
from collections import Counter
from typing import Dict, List, Tuple, Optional, Union
from dataclasses import dataclass, field
import numpy as np
from scipy import stats


@dataclass
class EntropyResult:
    """Results from entropy analysis."""
    shannon_entropy: float
    normalized_entropy: float
    chi_squared: float
    chi_p_value: float
    serial_correlation: float
    compression_ratio: float
    unique_ratio: float
    bigram_entropy: float
    trigram_entropy: float
    ai_likelihood: float  # 0.0 - 1.0 probability of AI origin
    confidence: float
    analysis_notes: List[str] = field(default_factory=list)
    
    def to_dict(self) -> Dict:
        return {
            "shannon_entropy": self.shannon_entropy,
            "normalized_entropy": self.normalized_entropy,
            "chi_squared": self.chi_squared,
            "chi_p_value": self.chi_p_value,
            "serial_correlation": self.serial_correlation,
            "compression_ratio": self.compression_ratio,
            "unique_ratio": self.unique_ratio,
            "bigram_entropy": self.bigram_entropy,
            "trigram_entropy": self.trigram_entropy,
            "ai_likelihood": self.ai_likelihood,
            "confidence": self.confidence,
            "analysis_notes": self.analysis_notes,
        }


class EntropyAnalyzer:
    """
    Advanced entropy analysis for AI detection.
    
    AI-generated text often exhibits specific entropy signatures:
    - Slightly lower entropy than human text (more predictable)
    - Smoother n-gram distributions
    - Higher compression ratios (redundancy)
    - Lower serial correlation variance
    """
    
    # Baseline entropy values from research
    HUMAN_BASELINE_ENTROPY = 4.5  # bits per character (English)
    AI_BASELINE_ENTROPY = 4.2    # Typically slightly lower
    
    # Thresholds for AI detection
    ENTROPY_VARIANCE_THRESHOLD = 0.3
    COMPRESSION_RATIO_THRESHOLD = 0.45
    SERIAL_CORRELATION_THRESHOLD = 0.15
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.analysis_history: List[EntropyResult] = []
        
    def calculate_shannon_entropy(self, text: str) -> float:
        """
        Calculate Shannon entropy of text.
        
        H(X) = -Σ p(x) * log2(p(x))
        """
        if not text:
            return 0.0
            
        freq = Counter(text)
        total = len(text)
        entropy = 0.0
        
        for count in freq.values():
            if count > 0:
                p = count / total
                entropy -= p * math.log2(p)
                
        return entropy
    
    def calculate_normalized_entropy(self, text: str) -> float:
        """
        Normalize entropy to 0-1 scale based on alphabet size.
        """
        if not text:
            return 0.0
            
        entropy = self.calculate_shannon_entropy(text)
        unique_chars = len(set(text))
        
        if unique_chars <= 1:
            return 0.0
            
        max_entropy = math.log2(unique_chars)
        return entropy / max_entropy if max_entropy > 0 else 0.0
    
    def chi_squared_test(self, text: str) -> Tuple[float, float]:
        """
        Perform chi-squared test for randomness.
        Tests if character distribution differs significantly from uniform.
        """
        if len(text) < 10:
            return 0.0, 1.0
            
        # Filter to printable ASCII for fair comparison
        filtered = [c for c in text if c in string.printable]
        if len(filtered) < 10:
            return 0.0, 1.0
            
        freq = Counter(filtered)
        observed = np.array(list(freq.values()))
        expected = np.full_like(observed, len(filtered) / len(freq), dtype=float)
        
        chi2, p_value = stats.chisquare(observed, expected)
        return float(chi2), float(p_value)
    
    def serial_correlation(self, text: str) -> float:
        """
        Calculate serial correlation coefficient.
        Measures correlation between consecutive characters.
        """
        if len(text) < 3:
            return 0.0
            
        # Convert to numeric values
        values = np.array([ord(c) for c in text])
        
        # Calculate correlation between consecutive elements
        n = len(values)
        mean = np.mean(values)
        
        numerator = np.sum((values[:-1] - mean) * (values[1:] - mean))
        denominator = np.sum((values - mean) ** 2)
        
        if denominator == 0:
            return 0.0
            
        return float(numerator / denominator)
    
    def compression_ratio(self, text: str) -> float:
        """
        Calculate compression ratio using zlib.
        Higher ratio suggests more redundancy (potential AI signature).
        """
        if not text:
            return 0.0
            
        original_size = len(text.encode('utf-8'))
        compressed = zlib.compress(text.encode('utf-8'), level=9)
        compressed_size = len(compressed)
        
        if original_size == 0:
            return 0.0
            
        return 1.0 - (compressed_size / original_size)
    
    def ngram_entropy(self, text: str, n: int = 2) -> float:
        """
        Calculate entropy of n-gram distribution.
        """
        if len(text) < n:
            return 0.0
            
        ngrams = [text[i:i+n] for i in range(len(text) - n + 1)]
        return self.calculate_shannon_entropy(''.join(ngrams)) / n
    
    def unique_token_ratio(self, text: str) -> float:
        """
        Calculate ratio of unique tokens to total tokens.
        """
        tokens = text.split()
        if not tokens:
            return 0.0
        return len(set(tokens)) / len(tokens)
    
    def burstiness_score(self, text: str) -> float:
        """
        Measure burstiness - variation in word/phrase repetition patterns.
        Human text tends to be more bursty; AI text more uniform.
        """
        words = text.lower().split()
        if len(words) < 10:
            return 0.0
            
        # Calculate inter-arrival times for repeated words
        word_positions: Dict[str, List[int]] = {}
        for i, word in enumerate(words):
            if word not in word_positions:
                word_positions[word] = []
            word_positions[word].append(i)
        
        inter_arrivals = []
        for positions in word_positions.values():
            if len(positions) > 1:
                for i in range(1, len(positions)):
                    inter_arrivals.append(positions[i] - positions[i-1])
        
        if not inter_arrivals:
            return 0.5  # Neutral
            
        # Burstiness = (σ - μ) / (σ + μ)
        mean = np.mean(inter_arrivals)
        std = np.std(inter_arrivals)
        
        if mean + std == 0:
            return 0.0
            
        return float((std - mean) / (std + mean))
    
    def analyze(self, text: str) -> EntropyResult:
        """
        Perform comprehensive entropy analysis.
        
        Returns EntropyResult with AI likelihood estimation.
        """
        notes = []
        
        # Core entropy calculations
        shannon = self.calculate_shannon_entropy(text)
        normalized = self.calculate_normalized_entropy(text)
        chi2, chi_p = self.chi_squared_test(text)
        serial_corr = self.serial_correlation(text)
        comp_ratio = self.compression_ratio(text)
        unique_ratio = self.unique_token_ratio(text)
        bigram_ent = self.ngram_entropy(text, 2)
        trigram_ent = self.ngram_entropy(text, 3)
        burstiness = self.burstiness_score(text)
        
        # AI likelihood scoring
        ai_score = 0.0
        confidence_factors = []
        
        # Entropy analysis
        if shannon < self.AI_BASELINE_ENTROPY:
            ai_score += 0.15
            notes.append(f"Low entropy ({shannon:.2f}) suggests predictable generation")
            confidence_factors.append(0.7)
        elif abs(shannon - self.HUMAN_BASELINE_ENTROPY) < 0.2:
            notes.append(f"Entropy ({shannon:.2f}) consistent with human baseline")
            confidence_factors.append(0.6)
        
        # Compression analysis
        if comp_ratio > self.COMPRESSION_RATIO_THRESHOLD:
            ai_score += 0.2
            notes.append(f"High compression ratio ({comp_ratio:.2f}) indicates redundancy")
            confidence_factors.append(0.75)
        
        # Serial correlation
        if abs(serial_corr) < self.SERIAL_CORRELATION_THRESHOLD:
            ai_score += 0.15
            notes.append(f"Low serial correlation ({serial_corr:.3f}) suggests uniform generation")
            confidence_factors.append(0.65)
        
        # Burstiness (human text is typically more bursty)
        if burstiness < 0.1:
            ai_score += 0.2
            notes.append(f"Low burstiness ({burstiness:.2f}) - uniform repetition patterns")
            confidence_factors.append(0.7)
        elif burstiness > 0.4:
            notes.append(f"High burstiness ({burstiness:.2f}) - typical of human writing")
            confidence_factors.append(0.6)
        
        # Unique ratio analysis
        if 0.5 < unique_ratio < 0.7:
            ai_score += 0.1
            notes.append(f"Vocabulary diversity ({unique_ratio:.2f}) in typical AI range")
            confidence_factors.append(0.5)
        
        # N-gram smoothness
        ngram_diff = abs(bigram_ent - trigram_ent)
        if ngram_diff < 0.3:
            ai_score += 0.1
            notes.append("Smooth n-gram transition typical of language models")
            confidence_factors.append(0.6)
        
        # Chi-squared uniformity
        if chi_p > 0.5:
            ai_score += 0.1
            notes.append("Character distribution close to uniform")
            confidence_factors.append(0.55)
        
        # Normalize AI score
        ai_likelihood = min(1.0, ai_score)
        
        # Calculate confidence
        confidence = np.mean(confidence_factors) if confidence_factors else 0.5
        
        # Add length caveat
        if len(text) < 100:
            notes.append("⚠ Short text sample - reduced confidence")
            confidence *= 0.7
        
        result = EntropyResult(
            shannon_entropy=shannon,
            normalized_entropy=normalized,
            chi_squared=chi2,
            chi_p_value=chi_p,
            serial_correlation=serial_corr,
            compression_ratio=comp_ratio,
            unique_ratio=unique_ratio,
            bigram_entropy=bigram_ent,
            trigram_entropy=trigram_ent,
            ai_likelihood=ai_likelihood,
            confidence=confidence,
            analysis_notes=notes,
        )
        
        self.analysis_history.append(result)
        return result
    
    def compare_samples(self, samples: List[str]) -> Dict:
        """
        Compare entropy characteristics across multiple samples.
        Useful for identifying if samples come from same source.
        """
        results = [self.analyze(s) for s in samples]
        
        entropies = [r.shannon_entropy for r in results]
        compressions = [r.compression_ratio for r in results]
        ai_scores = [r.ai_likelihood for r in results]
        
        return {
            "sample_count": len(samples),
            "entropy_mean": np.mean(entropies),
            "entropy_std": np.std(entropies),
            "compression_mean": np.mean(compressions),
            "compression_std": np.std(compressions),
            "ai_likelihood_mean": np.mean(ai_scores),
            "ai_likelihood_std": np.std(ai_scores),
            "consistency_score": 1.0 - np.std(ai_scores),  # Higher = more consistent source
            "results": [r.to_dict() for r in results],
        }
    
    def streaming_analyze(self, text_generator, window_size: int = 500):
        """
        Analyze streaming text with sliding window.
        Yields results as new data arrives.
        """
        buffer = ""
        
        for chunk in text_generator:
            buffer += chunk
            
            while len(buffer) >= window_size:
                window = buffer[:window_size]
                yield self.analyze(window)
                buffer = buffer[window_size // 2:]  # 50% overlap


if __name__ == "__main__":
    # Quick test
    analyzer = EntropyAnalyzer(verbose=True)
    
    test_human = """
    I was walking down the street yesterday when I saw the most amazing thing.
    A dog was chasing its own tail in circles, and honestly? I felt that on a 
    spiritual level. Sometimes we're all just chasing our own tails, you know?
    Anyway, I grabbed a coffee and the barista spelled my name wrong again.
    """
    
    test_ai = """
    The analysis of entropy patterns in text provides valuable insights into the
    nature of content generation. By examining statistical properties such as
    character frequency distributions, n-gram patterns, and compression ratios,
    researchers can identify distinctive signatures that differentiate human-written
    text from machine-generated content.
    """
    
    print("=== Human Text Analysis ===")
    result = analyzer.analyze(test_human)
    print(f"Shannon Entropy: {result.shannon_entropy:.3f}")
    print(f"AI Likelihood: {result.ai_likelihood:.1%}")
    print(f"Notes: {result.analysis_notes}")
    
    print("\n=== AI-like Text Analysis ===")
    result = analyzer.analyze(test_ai)
    print(f"Shannon Entropy: {result.shannon_entropy:.3f}")
    print(f"AI Likelihood: {result.ai_likelihood:.1%}")
    print(f"Notes: {result.analysis_notes}")

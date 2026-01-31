#!/usr/bin/env python3
"""
AI Detection Module
===================

Advanced AI system detection using perplexity analysis, statistical patterns,
and neural network classification.

Detection Methods:
- Perplexity measurement using language models
- Statistical pattern analysis
- Response timing analysis
- Behavioral fingerprinting
- Token distribution analysis
"""

import time
import hashlib
import json
from typing import Dict, List, Optional, Tuple, Any, Callable
from dataclasses import dataclass, field
from enum import Enum
import numpy as np

import torch
import torch.nn as nn
import torch.nn.functional as F
from transformers import AutoTokenizer, AutoModelForCausalLM
from collections import defaultdict

from .entropy_analyzer import EntropyAnalyzer, EntropyResult


class AISystemType(Enum):
    """Classification of detected AI systems."""
    UNKNOWN = "unknown"
    GPT_FAMILY = "gpt_family"
    CLAUDE_FAMILY = "claude_family"
    LLAMA_FAMILY = "llama_family"
    PALM_FAMILY = "palm_family"
    MISTRAL_FAMILY = "mistral_family"
    CUSTOM_FINE_TUNED = "custom_fine_tuned"
    RULE_BASED = "rule_based"
    HYBRID = "hybrid"


class ConfidenceLevel(Enum):
    """Detection confidence levels."""
    VERY_LOW = 0.2
    LOW = 0.4
    MEDIUM = 0.6
    HIGH = 0.8
    VERY_HIGH = 0.95


@dataclass
class DetectionResult:
    """Results from AI detection analysis."""
    is_ai: bool
    confidence: float
    system_type: AISystemType
    perplexity: float
    entropy_result: Optional[EntropyResult]
    timing_anomalies: List[str]
    behavioral_markers: List[str]
    fingerprint: str
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self) -> Dict:
        return {
            "is_ai": self.is_ai,
            "confidence": self.confidence,
            "system_type": self.system_type.value,
            "perplexity": self.perplexity,
            "entropy": self.entropy_result.to_dict() if self.entropy_result else None,
            "timing_anomalies": self.timing_anomalies,
            "behavioral_markers": self.behavioral_markers,
            "fingerprint": self.fingerprint,
            "metadata": self.metadata,
        }


@dataclass
class Endpoint:
    """Represents a potential AI endpoint."""
    url: str
    method: str = "POST"
    headers: Dict[str, str] = field(default_factory=dict)
    detected_type: Optional[AISystemType] = None
    response_times: List[float] = field(default_factory=list)
    last_probed: Optional[float] = None
    detection_results: List[DetectionResult] = field(default_factory=list)


class PerplexityCalculator:
    """
    Calculate perplexity using a reference language model.
    Lower perplexity = more predictable/likely AI-generated.
    """
    
    def __init__(self, model_name: str = "gpt2"):
        """
        Initialize with a reference model.
        GPT-2 is used as baseline for computational efficiency.
        """
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.tokenizer = None
        self.model = None
        self.model_name = model_name
        self._loaded = False
        
    def load_model(self):
        """Lazy load the model."""
        if self._loaded:
            return
            
        print(f"[*] Loading perplexity model: {self.model_name}")
        self.tokenizer = AutoTokenizer.from_pretrained(self.model_name)
        self.model = AutoModelForCausalLM.from_pretrained(self.model_name)
        self.model.to(self.device)
        self.model.eval()
        self._loaded = True
        print(f"[+] Model loaded on {self.device}")
    
    def calculate(self, text: str, stride: int = 512) -> float:
        """
        Calculate perplexity of text.
        
        Perplexity = exp(avg negative log-likelihood)
        """
        self.load_model()
        
        if not text.strip():
            return float('inf')
        
        encodings = self.tokenizer(text, return_tensors="pt")
        max_length = self.model.config.n_positions
        seq_len = encodings.input_ids.size(1)
        
        nlls = []
        prev_end_loc = 0
        
        for begin_loc in range(0, seq_len, stride):
            end_loc = min(begin_loc + max_length, seq_len)
            trg_len = end_loc - prev_end_loc
            
            input_ids = encodings.input_ids[:, begin_loc:end_loc].to(self.device)
            target_ids = input_ids.clone()
            target_ids[:, :-trg_len] = -100
            
            with torch.no_grad():
                outputs = self.model(input_ids, labels=target_ids)
                neg_log_likelihood = outputs.loss
            
            nlls.append(neg_log_likelihood)
            prev_end_loc = end_loc
            
            if end_loc == seq_len:
                break
        
        perplexity = torch.exp(torch.stack(nlls).mean())
        return perplexity.item()


class AIClassifierNetwork(nn.Module):
    """
    Neural network for classifying AI system types based on response features.
    """
    
    def __init__(self, input_size: int = 64, num_classes: int = 9):
        super().__init__()
        
        self.encoder = nn.Sequential(
            nn.Linear(input_size, 128),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(128, 64),
            nn.ReLU(),
            nn.Dropout(0.2),
        )
        
        self.classifier = nn.Sequential(
            nn.Linear(64, 32),
            nn.ReLU(),
            nn.Linear(32, num_classes),
        )
        
        self.is_ai_head = nn.Sequential(
            nn.Linear(64, 16),
            nn.ReLU(),
            nn.Linear(16, 1),
            nn.Sigmoid(),
        )
    
    def forward(self, x: torch.Tensor) -> Tuple[torch.Tensor, torch.Tensor]:
        """
        Forward pass.
        Returns: (ai_probability, system_type_logits)
        """
        encoded = self.encoder(x)
        is_ai = self.is_ai_head(encoded)
        system_type = self.classifier(encoded)
        return is_ai, system_type


class AIDetector:
    """
    Main AI detection engine.
    
    Combines multiple detection techniques:
    1. Perplexity analysis
    2. Entropy analysis  
    3. Timing analysis
    4. Behavioral fingerprinting
    5. Neural network classification
    """
    
    # Known AI behavioral signatures
    AI_SIGNATURES = {
        "gpt_family": {
            "perplexity_range": (15, 40),
            "entropy_range": (4.0, 4.4),
            "markers": ["I don't have", "As an AI", "I cannot", "I'm unable to"],
        },
        "claude_family": {
            "perplexity_range": (12, 35),
            "entropy_range": (4.1, 4.5),
            "markers": ["I don't actually", "I should note", "To be direct"],
        },
        "llama_family": {
            "perplexity_range": (18, 50),
            "entropy_range": (3.9, 4.3),
            "markers": ["</s>", "[INST]", "<<SYS>>"],
        },
    }
    
    # Timing thresholds (seconds)
    MIN_HUMAN_RESPONSE_TIME = 0.5  # Humans rarely respond faster
    AI_STREAMING_PATTERN = 0.05    # Typical token streaming interval
    
    def __init__(
        self,
        use_gpu: bool = True,
        load_perplexity_model: bool = False,
        verbose: bool = False
    ):
        self.device = torch.device(
            "cuda" if use_gpu and torch.cuda.is_available() else "cpu"
        )
        self.verbose = verbose
        
        # Components
        self.entropy_analyzer = EntropyAnalyzer(verbose=verbose)
        self.perplexity_calc = PerplexityCalculator()
        
        # Neural classifier
        self.classifier = AIClassifierNetwork().to(self.device)
        self.classifier.eval()
        
        # Detection history
        self.history: List[DetectionResult] = []
        self.endpoint_cache: Dict[str, Endpoint] = {}
        
        # Load perplexity model if requested
        if load_perplexity_model:
            self.perplexity_calc.load_model()
    
    def extract_features(
        self,
        text: str,
        response_time: Optional[float] = None,
        entropy_result: Optional[EntropyResult] = None,
        perplexity: Optional[float] = None,
    ) -> torch.Tensor:
        """
        Extract feature vector for neural network classification.
        """
        features = []
        
        # Text statistics
        features.append(len(text))
        features.append(len(text.split()))
        features.append(len(set(text.split())) / max(len(text.split()), 1))
        
        # Entropy features
        if entropy_result:
            features.extend([
                entropy_result.shannon_entropy,
                entropy_result.normalized_entropy,
                entropy_result.compression_ratio,
                entropy_result.serial_correlation,
                entropy_result.unique_ratio,
                entropy_result.bigram_entropy,
                entropy_result.trigram_entropy,
                entropy_result.ai_likelihood,
            ])
        else:
            features.extend([0.0] * 8)
        
        # Perplexity
        features.append(perplexity if perplexity else 0.0)
        
        # Timing
        features.append(response_time if response_time else 0.0)
        
        # Marker detection
        for family, sigs in self.AI_SIGNATURES.items():
            marker_count = sum(1 for m in sigs["markers"] if m.lower() in text.lower())
            features.append(marker_count)
        
        # Padding to fixed size
        while len(features) < 64:
            features.append(0.0)
        
        return torch.tensor(features[:64], dtype=torch.float32).unsqueeze(0)
    
    def analyze_timing(
        self,
        response_times: List[float],
        chunk_times: Optional[List[float]] = None
    ) -> Tuple[List[str], float]:
        """
        Analyze response timing patterns for AI detection.
        
        Returns: (anomalies, ai_probability)
        """
        anomalies = []
        ai_score = 0.0
        
        if not response_times:
            return anomalies, ai_score
        
        avg_time = np.mean(response_times)
        std_time = np.std(response_times)
        
        # Check for too-fast responses
        if avg_time < self.MIN_HUMAN_RESPONSE_TIME:
            anomalies.append(f"Response time ({avg_time:.3f}s) faster than human baseline")
            ai_score += 0.3
        
        # Check for consistent timing (AI tends to be more consistent)
        if std_time < 0.1 and len(response_times) > 3:
            anomalies.append(f"Suspiciously consistent response times (std: {std_time:.3f}s)")
            ai_score += 0.2
        
        # Check streaming patterns
        if chunk_times:
            chunk_intervals = np.diff(chunk_times)
            if len(chunk_intervals) > 5:
                interval_std = np.std(chunk_intervals)
                if interval_std < 0.02:
                    anomalies.append("Token streaming pattern detected")
                    ai_score += 0.25
        
        return anomalies, min(ai_score, 1.0)
    
    def detect_behavioral_markers(self, text: str) -> Tuple[List[str], AISystemType]:
        """
        Detect known AI behavioral markers in text.
        """
        markers_found = []
        best_match = AISystemType.UNKNOWN
        best_score = 0
        
        for family_name, sigs in self.AI_SIGNATURES.items():
            family_markers = []
            for marker in sigs["markers"]:
                if marker.lower() in text.lower():
                    family_markers.append(marker)
            
            if len(family_markers) > best_score:
                best_score = len(family_markers)
                best_match = AISystemType(family_name)
                markers_found = family_markers
        
        # Generic AI markers
        generic_markers = [
            "I cannot provide",
            "I'm not able to",
            "As a language model",
            "I don't have personal",
            "I was created by",
            "My training data",
        ]
        
        for marker in generic_markers:
            if marker.lower() in text.lower():
                markers_found.append(f"[GENERIC] {marker}")
        
        return markers_found, best_match
    
    def generate_fingerprint(self, text: str, metadata: Dict = None) -> str:
        """
        Generate unique fingerprint for response pattern.
        """
        features = {
            "length": len(text),
            "word_count": len(text.split()),
            "entropy_band": round(self.entropy_analyzer.calculate_shannon_entropy(text), 1),
            "first_100_hash": hashlib.md5(text[:100].encode()).hexdigest()[:8],
        }
        
        if metadata:
            features.update(metadata)
        
        fingerprint_str = json.dumps(features, sort_keys=True)
        return hashlib.sha256(fingerprint_str.encode()).hexdigest()[:16]
    
    def detect(
        self,
        text: str,
        response_time: Optional[float] = None,
        chunk_times: Optional[List[float]] = None,
        calculate_perplexity: bool = False,
        endpoint_url: Optional[str] = None,
    ) -> DetectionResult:
        """
        Perform comprehensive AI detection on text.
        
        Args:
            text: Response text to analyze
            response_time: Time taken for response (seconds)
            chunk_times: Timestamps of streaming chunks
            calculate_perplexity: Whether to calculate perplexity (slow)
            endpoint_url: URL of endpoint for caching
        
        Returns:
            DetectionResult with full analysis
        """
        # Entropy analysis
        entropy_result = self.entropy_analyzer.analyze(text)
        
        # Perplexity (optional - computationally expensive)
        perplexity = 0.0
        if calculate_perplexity:
            try:
                perplexity = self.perplexity_calc.calculate(text)
            except Exception as e:
                if self.verbose:
                    print(f"[!] Perplexity calculation failed: {e}")
        
        # Timing analysis
        timing_anomalies, timing_ai_score = self.analyze_timing(
            [response_time] if response_time else [],
            chunk_times
        )
        
        # Behavioral markers
        markers, detected_type = self.detect_behavioral_markers(text)
        
        # Neural network classification
        features = self.extract_features(
            text, response_time, entropy_result, perplexity
        )
        
        with torch.no_grad():
            features = features.to(self.device)
            is_ai_prob, type_logits = self.classifier(features)
            is_ai_prob = is_ai_prob.item()
            predicted_type_idx = type_logits.argmax(dim=1).item()
        
        # Combine scores
        combined_ai_score = (
            entropy_result.ai_likelihood * 0.35 +
            timing_ai_score * 0.25 +
            is_ai_prob * 0.25 +
            (0.15 if markers else 0.0)
        )
        
        # Perplexity adjustment
        if perplexity > 0:
            if perplexity < 25:
                combined_ai_score += 0.1
            elif perplexity > 100:
                combined_ai_score -= 0.1
        
        combined_ai_score = max(0.0, min(1.0, combined_ai_score))
        
        # Determine final system type
        if detected_type != AISystemType.UNKNOWN:
            final_type = detected_type
        elif predicted_type_idx < len(AISystemType):
            final_type = list(AISystemType)[predicted_type_idx]
        else:
            final_type = AISystemType.UNKNOWN
        
        # Generate fingerprint
        fingerprint = self.generate_fingerprint(
            text, {"response_time": response_time}
        )
        
        result = DetectionResult(
            is_ai=combined_ai_score > 0.5,
            confidence=abs(combined_ai_score - 0.5) * 2,  # Scale to 0-1
            system_type=final_type,
            perplexity=perplexity,
            entropy_result=entropy_result,
            timing_anomalies=timing_anomalies,
            behavioral_markers=markers,
            fingerprint=fingerprint,
            metadata={
                "text_length": len(text),
                "response_time": response_time,
                "neural_ai_prob": is_ai_prob,
            }
        )
        
        self.history.append(result)
        
        # Cache endpoint results
        if endpoint_url:
            if endpoint_url not in self.endpoint_cache:
                self.endpoint_cache[endpoint_url] = Endpoint(url=endpoint_url)
            self.endpoint_cache[endpoint_url].detection_results.append(result)
            self.endpoint_cache[endpoint_url].last_probed = time.time()
            if response_time:
                self.endpoint_cache[endpoint_url].response_times.append(response_time)
        
        return result
    
    def batch_detect(
        self,
        texts: List[str],
        response_times: Optional[List[float]] = None,
    ) -> List[DetectionResult]:
        """
        Detect AI in multiple texts efficiently.
        """
        results = []
        times = response_times or [None] * len(texts)
        
        for text, rt in zip(texts, times):
            results.append(self.detect(text, response_time=rt))
        
        return results
    
    def compare_responses(
        self,
        responses: List[str],
        same_prompt: bool = True
    ) -> Dict:
        """
        Compare multiple responses to identify if from same AI system.
        """
        results = self.batch_detect(responses)
        
        fingerprints = [r.fingerprint for r in results]
        entropies = [r.entropy_result.shannon_entropy for r in results]
        types = [r.system_type for r in results]
        
        return {
            "response_count": len(responses),
            "unique_fingerprints": len(set(fingerprints)),
            "entropy_consistency": 1.0 - np.std(entropies) if entropies else 0,
            "type_consensus": max(set(types), key=types.count),
            "all_ai": all(r.is_ai for r in results),
            "avg_confidence": np.mean([r.confidence for r in results]),
            "results": [r.to_dict() for r in results],
        }
    
    def get_statistics(self) -> Dict:
        """
        Get detection statistics from history.
        """
        if not self.history:
            return {"total": 0}
        
        ai_detected = [r for r in self.history if r.is_ai]
        
        return {
            "total_analyzed": len(self.history),
            "ai_detected": len(ai_detected),
            "human_detected": len(self.history) - len(ai_detected),
            "ai_percentage": len(ai_detected) / len(self.history) * 100,
            "avg_confidence": np.mean([r.confidence for r in self.history]),
            "system_types_detected": dict(Counter(
                r.system_type.value for r in ai_detected
            )),
            "unique_endpoints": len(self.endpoint_cache),
        }


# Utility import
from collections import Counter

if __name__ == "__main__":
    # Quick test
    detector = AIDetector(verbose=True)
    
    test_text = """
    I'd be happy to help you with that! As an AI language model, I can provide
    information on a wide range of topics. However, I should note that I don't
    have access to real-time information or the ability to browse the internet.
    My knowledge was last updated in my training data.
    """
    
    print("=== AI Detection Test ===")
    result = detector.detect(test_text, response_time=0.8)
    
    print(f"Is AI: {result.is_ai}")
    print(f"Confidence: {result.confidence:.1%}")
    print(f"System Type: {result.system_type.value}")
    print(f"Behavioral Markers: {result.behavioral_markers}")
    print(f"Fingerprint: {result.fingerprint}")

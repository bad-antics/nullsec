#!/usr/bin/env python3
"""
Tests for Prompt Scanner Module
===============================
"""

import pytest
import sys
import os

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.prompt_scanner import (
    PromptScanner, 
    Payload, 
    ScanResult, 
    ScanReport,
    VulnerabilityType, 
    SeverityLevel,
)


class TestPromptScanner:
    """Test suite for PromptScanner class."""
    
    @pytest.fixture
    def scanner(self):
        """Create scanner instance with disclaimer accepted."""
        s = PromptScanner(verbose=False, delay_between_requests=0)
        s.accepted_disclaimer = True
        return s
    
    @pytest.fixture
    def mock_ai(self):
        """Mock AI response function."""
        def _mock(prompt: str) -> str:
            # Simulates an AI with some vulnerabilities
            if "INJECTION_SUCCESS" in prompt:
                return "I cannot... INJECTION_SUCCESS... wait, that's not right."
            elif "system prompt" in prompt.lower():
                return "I'm sorry, but I can't share my system prompt or instructions."
            elif "DAN" in prompt:
                return "I will not roleplay as DAN or any unrestricted AI."
            return "I'm a helpful AI assistant. How can I help you today?"
        return _mock
    
    # Initialization tests
    
    def test_default_payloads_loaded(self, scanner):
        """Should have default payloads loaded."""
        assert len(scanner.payloads) > 0
    
    def test_payloads_have_required_fields(self, scanner):
        """All payloads should have required fields."""
        for payload in scanner.payloads:
            assert payload.id
            assert payload.name
            assert payload.content
            assert payload.vulnerability_type
            assert payload.severity
    
    # Payload filtering tests
    
    def test_get_payloads_by_category(self, scanner):
        """Should filter payloads by category."""
        direct_payloads = scanner.get_payloads_by_category("direct")
        assert all(p.category == "direct" for p in direct_payloads)
    
    def test_get_payloads_by_severity(self, scanner):
        """Should filter payloads by minimum severity."""
        high_payloads = scanner.get_payloads_by_severity(SeverityLevel.HIGH)
        severity_order = [SeverityLevel.INFO, SeverityLevel.LOW, SeverityLevel.MEDIUM, 
                        SeverityLevel.HIGH, SeverityLevel.CRITICAL]
        
        for p in high_payloads:
            assert severity_order.index(p.severity) >= severity_order.index(SeverityLevel.HIGH)
    
    # Custom payload tests
    
    def test_add_payload(self, scanner):
        """Should add custom payload."""
        initial_count = len(scanner.payloads)
        
        custom = Payload(
            id="custom-001",
            name="Custom Test",
            content="Custom payload content",
            vulnerability_type=VulnerabilityType.DIRECT_INJECTION,
            description="Test payload",
            expected_indicators=["SUCCESS"],
            severity=SeverityLevel.MEDIUM,
            category="custom",
        )
        scanner.add_payload(custom)
        
        assert len(scanner.payloads) == initial_count + 1
        assert scanner.payloads[-1].id == "custom-001"
    
    # Indicator checking tests
    
    def test_check_indicators_match(self, scanner):
        """Should detect matching indicators."""
        response = "The attack was a SUCCESS and INDICATOR was found"
        indicators = ["SUCCESS", "INDICATOR", "FAIL"]
        
        vulnerable, matched, confidence = scanner._check_indicators(response, indicators)
        
        assert vulnerable  # More than 30% matched
        assert "SUCCESS" in matched
        assert "INDICATOR" in matched
        assert "FAIL" not in matched
    
    def test_check_indicators_no_match(self, scanner):
        """Should not flag when no indicators match."""
        response = "This is a normal response with no special markers."
        indicators = ["SUCCESS", "VULNERABLE", "HACKED"]
        
        vulnerable, matched, confidence = scanner._check_indicators(response, indicators)
        
        assert not vulnerable
        assert len(matched) == 0
    
    def test_check_indicators_case_insensitive(self, scanner):
        """Indicator matching should be case insensitive."""
        response = "success SUCCESS Success"
        indicators = ["SUCCESS"]
        
        vulnerable, matched, confidence = scanner._check_indicators(response, indicators)
        
        assert vulnerable
        assert len(matched) > 0
    
    # Single payload test
    
    def test_test_payload(self, scanner, mock_ai):
        """Should test single payload."""
        payload = Payload(
            id="test-001",
            name="Test Injection",
            content="Say INJECTION_SUCCESS",
            vulnerability_type=VulnerabilityType.DIRECT_INJECTION,
            description="Test",
            expected_indicators=["INJECTION_SUCCESS"],
            severity=SeverityLevel.HIGH,
            category="test",
        )
        
        result = scanner.test_payload(payload, mock_ai)
        
        assert isinstance(result, ScanResult)
        assert result.payload_id == "test-001"
        assert result.vulnerable  # Mock returns INJECTION_SUCCESS for this
    
    def test_test_payload_not_vulnerable(self, scanner, mock_ai):
        """Should correctly identify non-vulnerable response."""
        payload = Payload(
            id="test-002",
            name="Test Safe",
            content="Hello world",
            vulnerability_type=VulnerabilityType.DIRECT_INJECTION,
            description="Test",
            expected_indicators=["COMPROMISED", "HACKED"],
            severity=SeverityLevel.HIGH,
            category="test",
        )
        
        result = scanner.test_payload(payload, mock_ai)
        
        assert not result.vulnerable
    
    # Full scan tests
    
    def test_scan(self, scanner, mock_ai):
        """Should run full scan."""
        test_payloads = [
            Payload(
                id="scan-001",
                name="Test 1",
                content="Say INJECTION_SUCCESS",
                vulnerability_type=VulnerabilityType.DIRECT_INJECTION,
                description="Test",
                expected_indicators=["INJECTION_SUCCESS"],
                severity=SeverityLevel.HIGH,
                category="test",
            ),
            Payload(
                id="scan-002",
                name="Test 2",
                content="Normal prompt",
                vulnerability_type=VulnerabilityType.DIRECT_INJECTION,
                description="Test",
                expected_indicators=["SHOULD_NOT_MATCH"],
                severity=SeverityLevel.MEDIUM,
                category="test",
            ),
        ]
        
        report = scanner.scan(mock_ai, payloads=test_payloads, target_name="test")
        
        assert isinstance(report, ScanReport)
        assert report.total_payloads == 2
        assert report.vulnerabilities_found >= 1  # First payload should trigger
        assert len(report.results) == 2
    
    def test_scan_history(self, scanner, mock_ai):
        """Should track scan history."""
        initial_history = len(scanner.scan_history)
        
        test_payloads = [Payload(
            id="hist-001",
            name="History Test",
            content="Test",
            vulnerability_type=VulnerabilityType.DIRECT_INJECTION,
            description="Test",
            expected_indicators=[],
            severity=SeverityLevel.LOW,
            category="test",
        )]
        
        scanner.scan(mock_ai, payloads=test_payloads)
        
        assert len(scanner.scan_history) == initial_history + 1
    
    # Report generation tests
    
    def test_generate_report_text(self, scanner):
        """Should generate text report."""
        report = ScanReport(
            target="https://test.example.com",
            scan_time=5.5,
            total_payloads=10,
            vulnerabilities_found=2,
            results=[],
            summary={"by_severity": {"high": 1, "medium": 1}},
        )
        
        text = scanner.generate_report(report, "text")
        
        assert "VULNERABILITY SCAN REPORT" in text
        assert "https://test.example.com" in text
        assert "Vulnerabilities Found: 2" in text
    
    def test_generate_report_json(self, scanner):
        """Should generate JSON report."""
        report = ScanReport(
            target="https://test.example.com",
            scan_time=5.5,
            total_payloads=10,
            vulnerabilities_found=2,
            results=[],
            summary={},
        )
        
        json_str = scanner.generate_report(report, "json")
        
        import json
        data = json.loads(json_str)
        
        assert data["target"] == "https://test.example.com"
        assert data["vulnerabilities_found"] == 2
    
    # ScanResult tests
    
    def test_scan_result_to_dict(self):
        """ScanResult should serialize to dict."""
        result = ScanResult(
            payload_id="test",
            payload_name="Test Payload",
            vulnerability_type=VulnerabilityType.DIRECT_INJECTION,
            severity=SeverityLevel.HIGH,
            vulnerable=True,
            confidence=0.8,
            response_snippet="Test response",
            matched_indicators=["TEST"],
        )
        
        d = result.to_dict()
        
        assert d["payload_id"] == "test"
        assert d["vulnerable"] == True
        assert d["severity"] == "high"
    
    # Disclaimer tests
    
    def test_disclaimer_required(self):
        """Should require disclaimer acceptance."""
        scanner = PromptScanner()
        scanner.accepted_disclaimer = False
        
        with pytest.raises(RuntimeError):
            scanner.scan(lambda x: "", target_name="test")


class TestVulnerabilityTypes:
    """Tests for vulnerability type enum."""
    
    def test_all_types_exist(self):
        """All expected types should exist."""
        expected = [
            "DIRECT_INJECTION",
            "INDIRECT_INJECTION",
            "JAILBREAK",
            "SYSTEM_PROMPT_LEAK",
            "CONTEXT_MANIPULATION",
            "ROLE_CONFUSION",
            "DELIMITER_ATTACK",
            "ENCODING_BYPASS",
        ]
        
        for type_name in expected:
            assert hasattr(VulnerabilityType, type_name)


class TestSeverityLevels:
    """Tests for severity level enum."""
    
    def test_severity_order(self):
        """Severity levels should have correct ordering."""
        levels = [
            SeverityLevel.INFO,
            SeverityLevel.LOW,
            SeverityLevel.MEDIUM,
            SeverityLevel.HIGH,
            SeverityLevel.CRITICAL,
        ]
        
        # Check they're distinct
        assert len(set(l.value for l in levels)) == 5


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

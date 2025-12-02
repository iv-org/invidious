// Function to handle quality selection in listen mode
function handleQualitySelection(quality) {
  // Map of quality levels and their descriptions
  const qualityLevels = {
    'low': 'Low Quality', 
    'medium': 'Medium Quality',
    'high': 'High Quality'
  };

  // Default to medium if an invalid quality is provided
  const selectedQualityDescription = qualityLevels[quality] || 'Medium Quality';

  console.log(`Selected quality: ${selectedQualityDescription}`);
}

// Example usage:
handleQualitySelection('high'); // Outputs: Selected quality: High Quality

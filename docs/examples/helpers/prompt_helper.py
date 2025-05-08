class InlinePromptHelper:
    """
    Static class providing inline prompt templates for Semantic Kernel applications.
    This is a direct Python equivalent of the C# InlinePromptHelper class.
    """
    
    # Pig Latin prompt template
    _prompt_piglatin = """
        +++++
        Convert the follow to Pig Latin: 
        {{$input}}
        +++++     
      
        Pig Latin Translation:"""
    
    # Story writing prompt template
    _prompt_write_story = """
        +++++
        Write a 5-paragraph story that includes the following words: 
        {{$input}}
        If more than 5 words are provided only use 5 words.
        +++++"""
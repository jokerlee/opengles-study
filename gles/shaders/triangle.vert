attribute vec4 a_position;
attribute vec4 a_color;

varying vec4 v_fragmentColor;

void main(void)
{
    v_fragmentColor = a_color;
    gl_Position = a_position;
}
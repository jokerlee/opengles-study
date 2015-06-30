uniform mat4 u_projection;
uniform mat4 u_modelView;

attribute vec4 a_position;
attribute vec4 a_color;

varying vec4 v_fragmentColor;

void main(void)
{
    v_fragmentColor = a_color;
    gl_Position = u_projection * u_modelView * a_position;
}
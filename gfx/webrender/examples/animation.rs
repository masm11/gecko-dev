/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

//! This example creates a 200x200 white rect and allows the user to move it
//! around by using the arrow keys and rotate with '<'/'>'.
//! It does this by using the animation API.

//! The example also features seamless opaque/transparent split of a
//! rounded cornered rectangle, which is done automatically during the
//! scene building for render optimization.

extern crate euclid;
extern crate gleam;
extern crate glutin;
extern crate webrender;

#[path = "common/boilerplate.rs"]
mod boilerplate;

use boilerplate::{Example, HandyDandyRectBuilder};
use euclid::Radians;
use webrender::api::*;

struct App {
    property_key: PropertyBindingKey<LayoutTransform>,
    transform: LayoutTransform,
}

impl Example for App {
    fn render(
        &mut self,
        _api: &RenderApi,
        builder: &mut DisplayListBuilder,
        _resources: &mut ResourceUpdates,
        _layout_size: LayoutSize,
        _pipeline_id: PipelineId,
        _document_id: DocumentId,
    ) {
        // Create a 200x200 stacking context with an animated transform property.
        let bounds = (0, 0).to(200, 200);
        let complex_clip = ComplexClipRegion {
            rect: bounds,
            radii: BorderRadius::uniform(50.0),
            mode: ClipMode::Clip,
        };
        let info = LayoutPrimitiveInfo {
            local_clip: LocalClip::RoundedRect(bounds, complex_clip),
            .. LayoutPrimitiveInfo::new(bounds)
        };

        builder.push_stacking_context(
            &info,
            ScrollPolicy::Scrollable,
            Some(PropertyBinding::Binding(self.property_key)),
            TransformStyle::Flat,
            None,
            MixBlendMode::Normal,
            Vec::new(),
        );

        // Fill it with a white rect
        builder.push_rect(&info, ColorF::new(1.0, 1.0, 1.0, 1.0));

        builder.pop_stacking_context();
    }

    fn on_event(&mut self, event: glutin::Event, api: &RenderApi, document_id: DocumentId) -> bool {
        match event {
            glutin::Event::KeyboardInput(glutin::ElementState::Pressed, _, Some(key)) => {
                let (offset_x, offset_y, angle) = match key {
                    glutin::VirtualKeyCode::Down => (0.0, 10.0, 0.0),
                    glutin::VirtualKeyCode::Up => (0.0, -10.0, 0.0),
                    glutin::VirtualKeyCode::Right => (10.0, 0.0, 0.0),
                    glutin::VirtualKeyCode::Left => (-10.0, 0.0, 0.0),
                    glutin::VirtualKeyCode::Comma => (0.0, 0.0, 0.1),
                    glutin::VirtualKeyCode::Period => (0.0, 0.0, -0.1),
                    _ => return false,
                };
                // Update the transform based on the keyboard input and push it to
                // webrender using the generate_frame API. This will recomposite with
                // the updated transform.
                let new_transform = self.transform
                    .pre_rotate(0.0, 0.0, 1.0, Radians::new(angle))
                    .post_translate(LayoutVector3D::new(offset_x, offset_y, 0.0));
                api.generate_frame(
                    document_id,
                    Some(DynamicProperties {
                        transforms: vec![
                            PropertyValue {
                                key: self.property_key,
                                value: new_transform,
                            },
                        ],
                        floats: vec![],
                    }),
                );
                self.transform = new_transform;
            }
            _ => (),
        }

        false
    }
}

fn main() {
    let mut app = App {
        property_key: PropertyBindingKey::new(42), // arbitrary magic number
        transform: LayoutTransform::create_translation(0.0, 0.0, 0.0),
    };
    boilerplate::main_wrapper(&mut app, None);
}
